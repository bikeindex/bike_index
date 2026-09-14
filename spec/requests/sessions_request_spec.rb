require "rails_helper"

RSpec.describe SessionsController, type: :request do
  # The `auth` Set-Cookie line for the last response. A permanent (remember-me)
  # cookie carries an `expires=`; a session cookie doesn't.
  def auth_set_cookie
    Array(response.headers["Set-Cookie"]).join("\n").lines.find { |line| line.start_with?("auth=") }.to_s
  end

  describe "new" do
    it "renders the email-only first step, without a password field" do
      get "/session/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('autocomplete="username"')
      expect(response.body).to_not include('autocomplete="current-password"')
      # the field offers a correction for a mistyped domain, and is still the autofocused one
      expect(Capybara.string(response.body))
        .to have_css("[data-controller='ui--forms--email'] input#session_email[autofocus][required]")
    end
  end

  describe "identify" do
    def identify(email)
      post "/session/identify", params: {session: {email:}}
    end

    context "existing account" do
      let!(:user) { FactoryBot.create(:user_confirmed, email: "person@example.com") }
      it "renders the password step with the email preserved" do
        identify("person@example.com")
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:identify)
        expect(response.body).to include('autocomplete="current-password"')
        expect(response.body).to include("person@example.com")
      end
    end

    context "passwordless user" do
      let!(:user) { FactoryBot.create(:user_confirmed, email: "person@example.com", passwordless_user: true) }
      it "emails a sign in link rather than asking for a password" do
        ActionMailer::Base.deliveries = []
        Sidekiq::Testing.inline! do
          post "/session/identify", params: {session: {email: "person@example.com", remember_me: "1"}}
        end
        expect(response).to redirect_to(magic_link_sent_session_path)
        expect(session[:magic_link_remember_me]).to be_truthy
        expect(user.reload.magic_link_token).to be_present
        expect(ActionMailer::Base.deliveries.last.subject).to eq("Sign in to Bike Index")
      end
    end

    context "no account" do
      it "redirects to sign up with the email pre-filled" do
        identify("newperson@example.com")
        expect(response).to redirect_to(new_user_path(email: "newperson@example.com"))
      end
    end

    context "blank email" do
      it "re-renders the email step" do
        identify("")
        expect(response).to render_template(:new)
      end
    end

    context "GET (reload / bookmark / back)" do
      it "re-renders the email step instead of 404ing or attempting a login" do
        get "/session/identify"
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:new)
        expect(response.cookies["auth"]).to be_blank
      end
    end

    context "passwordless organization domain" do
      let!(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: ["passwordless_users"], user_email_domain: "party.edu")
      end
      it "renders the magic-link step for the org domain (even with no account yet)" do
        identify("newperson@party.edu")
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:identify)
        expect(response.body).to_not include('autocomplete="current-password"')
      end
    end

    context "sso organization domain" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: ["saml_sso"], user_email_domain: "sso.edu")
      end

      it "hands off to the IdP, skipping the credential step" do
        FactoryBot.create(:organization_saml_configuration, :active, organization:)
        identify("student@sso.edu")
        expect(response).to redirect_to(saml_init_path(org_slug: organization.to_param))
      end

      context "SAML config not yet live" do
        let!(:user) { FactoryBot.create(:user_confirmed, email: "student@sso.edu") }
        it "falls through to the password step rather than a broken SSO redirect" do
          identify("student@sso.edu")
          expect(response).to render_template(:identify)
          expect(response.body).to include('autocomplete="current-password"')
        end
      end
    end

    context "with rack_attack" do
      include_context :rack_attack

      it "returns 429 after exceeding the per-IP sign-in limit" do
        # Fresh email per request keeps each under the per-email throttle, so only per-IP trips
        throttled = rack_attack_throttled_response(limit: 10) do
          identify("person-#{SecureRandom.hex(4)}@example.com")
          response
        end
        expect(throttled.headers["retry-after"]).to eq "60"
      end

      it "returns 429 after exceeding the per-email sign-in limit" do
        throttled = rack_attack_throttled_response(limit: 5) do
          identify("person@example.com")
          response
        end
        expect(throttled.headers["retry-after"]).to eq "20"
      end
    end
  end

  describe "create_magic_link" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    it "sends the magic link" do
      expect(current_user.magic_link_token).to be_nil
      ActionMailer::Base.deliveries = []
      Sidekiq::Job.clear_all
      Sidekiq::Testing.inline! do
        post "/session/create_magic_link", params: {email: " #{current_user.email} "}
        expect(ActionMailer::Base.deliveries.count).to eq 1
        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to eq("Sign in to Bike Index")
        expect(mail.to).to eq([current_user.email])
        expect(current_user.reload.magic_link_token).not_to be_nil
      end
      expect(response).to redirect_to(magic_link_sent_session_path)
      follow_redirect!
      expect(response.body).to match("We sent you a magic sign in link")
    end
    context "unknown email" do
      it "redirects to login" do
        ActionMailer::Base.deliveries = []
        Sidekiq::Job.clear_all
        Sidekiq::Testing.inline! do
          post "/session/create_magic_link", params: {email: "something@stuff.bike"}
          expect(flash[:error]).to be_present
          expect(response).to redirect_to new_user_path
          expect(ActionMailer::Base.deliveries.count).to eq 0
        end
      end
    end
    context "passwordless email" do
      let!(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["passwordless_users"], user_email_domain: "party.edu", available_invitation_count: 1) }
      it "autogenerates the user without granting a role" do
        ActionMailer::Base.deliveries = []
        Sidekiq::Job.clear_all
        Sidekiq::Testing.inline! do
          # Just throw this in here because we don't have anywhere else that tests signup with user_email_domain present...
          expect { post "/session/create_magic_link", params: {email: "somethingcool@ party.edu"} }.to_not change(User, :count)
          expect {
            post "/session/create_magic_link", params: {email: "somethingcool@party.edu"}
          }.to change(User, :count).by 1
          # Claiming the domain for sign in doesn't grant a role in the organization
          expect(current_organization.organization_roles.count).to eq 0
          expect(ActionMailer::Base.deliveries.count).to eq 1
          mail = ActionMailer::Base.deliveries.last
          expect(mail.subject).to eq("Sign in to Bike Index")
          expect(mail.to).to eq(["somethingcool@party.edu"])
          user = User.last
          expect(user.confirmed?).to be_truthy
          expect(user.email).to eq "somethingcool@party.edu"
          expect(user.magic_link_token).to be_present
        end
      end

      context "also granting a role for the domain" do
        let!(:current_organization) do
          FactoryBot.create(:organization_with_organization_features,
            enabled_feature_slugs: ["passwordless_users", "user_role_for_user_email_domain"],
            user_email_domain: "party.edu", available_invitation_count: 1)
        end
        it "grants the member role" do
          ActionMailer::Base.deliveries = []
          Sidekiq::Job.clear_all
          Sidekiq::Testing.inline! do
            expect {
              post "/session/create_magic_link", params: {email: "somethingcool@party.edu"}
            }.to change(User, :count).by 1
          end
          organization_role = User.last.organization_roles.first
          expect(organization_role.organization).to eq current_organization
          expect(organization_role.sender_id).to be_blank
          expect(organization_role.role).to eq "member"
          # Granting the role must not add a second email on top of the sign in link
          expect(ActionMailer::Base.deliveries.map(&:subject)).to eq(["Sign in to Bike Index"])
        end
      end
    end

    context "sso organization email" do
      let!(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: ["saml_sso"], user_email_domain: "sso.edu")
      end
      let!(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :active, organization:) }
      it "forces SSO instead of sending a link" do
        ActionMailer::Base.deliveries = []
        post "/session/create_magic_link", params: {email: "student@sso.edu"}
        expect(response).to redirect_to(saml_init_path(org_slug: organization.to_param))
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
  end

  describe "new" do
    it "renders, storing return_to" do
      get "/session/new", params: {return_to: "/bikes/12?contact_owner=true"}
      expect(response.code).to eq "200"
      expect(response).to render_template(:new)
      expect(response).to render_template("layouts/application")
      expect(flash).to_not be_present
      expect(session[:return_to]).to eq "/bikes/12?contact_owner=true"
    end
    context "json format" do
      it "renders html (scanners request .json)" do
        get "/session/new.json"
        expect(response.code).to eq "200"
        expect(response).to render_template(:new)
      end
    end
    context "with partner" do
      it "renders the bikehub layout" do
        get "/session/new", params: {return_to: "/bikes/12?contact_owner=true", partner: "bikehub"}
        expect(session[:return_to]).to eq "/bikes/12?contact_owner=true"
        expect(response).to render_template("layouts/application_bikehub")
      end
    end
    context "with partner in session" do
      include_context :existing_doorkeeper_app
      it "renders the bikehub layout, naming the company" do
        get "/oauth/authorize", params: {client_id: doorkeeper_app.uid, response_type: "code",
                                         scope: "read_bikes", partner: "bikehub", company: "Some BikeHub"}
        expect(session[:partner]).to eq "bikehub"
        expect(session[:company]).to eq "Some BikeHub"

        get "/session/new"
        expect(response).to render_template("layouts/application_bikehub")
        expect(response.body).to match("Some BikeHub")
      end
    end
    context "signed in user" do
      # signed in for real: log_in's User.from_auth stub answers User.unconfirmed too,
      # and skip_if_signed_in asks that before it asks whether the user is confirmed
      let(:password) { "example_password2" }
      let(:user) { FactoryBot.create(:user_confirmed, password:, password_confirmation: password) }
      before { post "/session", params: {session: {email: user.email, password:}} }

      it "redirects to return_to, and drops one that would loop back to signing in" do
        get "/session/new", params: {return_to: "/bikes/12?contact_owner=true"}
        expect(response).to redirect_to "/bikes/12?contact_owner=true"

        ["/session/new", "/users/new/", "/users/new?something=true"].each do |looping_return_to|
          get "/session/new", params: {return_to: looping_return_to}
          expect(response).to redirect_to my_account_path
          expect(session[:return_to]).to be_blank
        end
      end
      context "unconfirmed" do
        let(:user) { FactoryBot.create(:user, password:, password_confirmation: password) }
        it "redirects to please_confirm_email, keeping return_to" do
          get "/session/new", params: {return_to: "/bikes/12?contact_owner=true"}
          expect(response).to redirect_to please_confirm_email_users_path
          expect(session[:return_to]).to eq "/bikes/12?contact_owner=true"
        end
      end
    end
  end

  describe "magic_link" do
    let!(:user) { FactoryBot.create(:user_confirmed) }

    # The emailed link is a GET, so it only renders the form that signs in
    it "renders the interstitial without spending the token" do
      token = user.refreshed_magic_link_token
      get "/session/magic_link", params: {token:}
      expect(response).to render_template(:magic_link)
      expect(response).to render_template("layouts/application")
      expect(assigns(:failure)).to be_falsey
      expect(signed_auth_cookie).to be_nil
      expect(user.reload.magic_link_token).to be_present
      expect(Capybara.string(response.body))
        .to have_css("form[action='/session/sign_in_with_magic_link'] input[name='token'][value='#{token}']", visible: :hidden)
    end

    # A dead token matches no user whatever killed it, so the reason comes from its timestamp
    context "incorrect_token" do
      def failure_for(token)
        get "/session/magic_link", params: {incorrect_token: token}
        expect(response).to render_template(:magic_link)
        expect(assigns(:failure)).to be_truthy
        expect(signed_auth_cookie).to be_nil
        response.body
      end

      it "names the timeout for a token older than the window" do
        stale = SecurityTokenizer.new_token((User::AUTH_TOKEN_EXPIRY + 1.minute).ago)
        expect(failure_for(stale)).to match(/link has expired/i)
      end

      it "says it was already used for a token inside the window" do
        expect(failure_for(SecurityTokenizer.new_token)).to match(/already been used/i)
      end

      it "stays generic for a token it can't read" do
        body = failure_for("mangled-by-some-email-client")
        expect(body).to match(/unable to authenticate/i)
        expect(body).to_not match(/already been used|link has expired/i)
      end
    end

    context "user signed in" do
      let(:password) { "example_password2" }
      let!(:user) { FactoryBot.create(:user_confirmed, password:, password_confirmation: password) }
      before { post "/session", params: {session: {email: user.email, password:}} }

      it "says they're already signed in and sends them home" do
        get "/session/magic_link", params: {token: SecurityTokenizer.new_token}
        expect(response).to redirect_to(my_account_url)
        expect(flash[:success]).to be_present
        expect(signed_auth_cookie).to_not be_nil
      end
    end
  end

  describe "sign_in_with_magic_link" do
    let!(:superadmin) { FactoryBot.create(:superuser) }

    it "signs in the superadmin with a refreshed token" do
      post "/session/sign_in_with_magic_link", params: {token: superadmin.refreshed_magic_link_token}
      expect(response).to redirect_to admin_root_url
      expect(superadmin.reload.magic_link_token).to be_nil
      expect(superadmin.last_login_at).to be_within(1.second).of Time.current
    end

    # find_by with a blank token matches IS NULL - nearly every user
    it "signs nobody in for a blank or missing token" do
      [{token: ""}, {}].each do |params|
        post "/session/sign_in_with_magic_link", params: params
        expect(response).to redirect_to magic_link_session_path(incorrect_token: params[:token])
        expect(response.cookies["auth"]).to be_blank
      end
    end

    # The biggest bucket of real failures: the link worked, and then got clicked again
    it "tells a spent token it was already used, not that something went wrong" do
      user = FactoryBot.create(:user_confirmed)
      token = user.refreshed_magic_link_token
      post "/session/sign_in_with_magic_link", params: {token:}
      expect(user.reload.magic_link_token).to be_nil
      delete "/session"

      post "/session/sign_in_with_magic_link", params: {token:}
      expect(response).to redirect_to magic_link_session_path(incorrect_token: token)
      follow_redirect!
      expect(response.body).to match(/already been used/i)
    end

    context "matching magic_link" do
      let(:user) { FactoryBot.create(:user_confirmed) }
      before { user.update_auth_token("magic_link_token") }

      it "signs in and redirects" do
        post "/session/sign_in_with_magic_link", params: {token: user.reload.magic_link_token},
          headers: {"HTTP_CF_CONNECTING_IP" => "66.66.66.66"}
        expect(response).to redirect_to my_account_url
        user.reload
        expect(signed_auth_cookie[1]).to eq(user.auth_token)
        expect(user.last_login_at).to be_within(1.second).of Time.current
        expect(user.last_login_ip).to eq "66.66.66.66"
        expect(user.magic_link_token).to be_blank
      end

      context "unconfirmed user" do
        let(:user) { FactoryBot.create(:user) }
        it "confirms the user" do
          expect(user.reload.confirmed?).to be_falsey
          post "/session/sign_in_with_magic_link", params: {token: user.magic_link_token}
          expect(response).to redirect_to my_account_url
          user.reload
          expect(signed_auth_cookie[1]).to eq(user.auth_token)
          expect(user.confirmed?).to be_truthy
          expect(user.magic_link_token).to be_blank
        end
      end

      context "expired magic_link" do
        before { user.update_auth_token("magic_link_token", (User::AUTH_TOKEN_EXPIRY + 1.minute).ago) }
        it "doesn't sign in, and leaves the token unspent" do
          og_token = user.reload.magic_link_token
          post "/session/sign_in_with_magic_link", params: {token: og_token},
            headers: {"HTTP_CF_CONNECTING_IP" => "66.66.66.66"}
          expect(response).to redirect_to(magic_link_session_path(incorrect_token: og_token))
          expect(signed_auth_cookie).to be_nil
          user.reload
          expect(user.magic_link_token).to eq og_token
          expect(user.last_login_at).to be_blank
          expect(user.last_login_ip).to be_blank
        end
      end

      context "banned user" do
        let(:user) { FactoryBot.create(:user_confirmed, banned: true) }
        it "says the account is locked" do
          post "/session/sign_in_with_magic_link", params: {token: user.reload.magic_link_token}
          expect(response).to redirect_to new_session_path
          expect(flash[:error]).to match "locked"
          expect(signed_auth_cookie).to be_nil
          user.reload
          expect(user.last_login_at).to be_blank
          expect(user.last_login_ip).to be_blank
        end
      end

      context "token matching no user" do
        it "redirects to the magic link page" do
          unknown_token = SecurityTokenizer.new_token
          post "/session/sign_in_with_magic_link", params: {token: unknown_token}
          expect(response).to redirect_to(magic_link_session_path(incorrect_token: unknown_token))
          expect(signed_auth_cookie).to be_nil
        end
      end
    end

    it "redirects back to return_to when passed (review-app banner)" do
      post "/session/sign_in_with_magic_link",
        params: {token: superadmin.refreshed_magic_link_token, return_to: "/bikes/12"}
      expect(response).to redirect_to "/bikes/12"
      expect(superadmin.reload.magic_link_token).to be_nil
    end

    context "sso organization email", :sso_organization do
      let(:user) { FactoryBot.create(:user_confirmed, email: "student@sso.edu") }

      it "hands a link minted before SSO off to the IdP" do
        post "/session/sign_in_with_magic_link", params: {token: user.refreshed_magic_link_token}
        expect(response).to redirect_to(saml_init_path(org_slug: organization.to_param))
        expect(response.cookies["auth"]).to be_blank
      end
    end

    context "passwordless user" do
      let(:user) { FactoryBot.create(:user_confirmed, passwordless_user: true) }

      it "offers to set a password" do
        post "/session/sign_in_with_magic_link", params: {token: user.refreshed_magic_link_token}
        expect(response).to redirect_to my_account_url
        expect(flash[:notice]).to eq({translation_key: :signed_in, url: update_password_form_with_reset_token_users_path})
        follow_redirect!
        expect(Capybara.string(response.body))
          .to have_link("set a password to sign in", href: update_password_form_with_reset_token_users_path)
      end

      context "organization passwordless user" do
        let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["passwordless_users"], user_email_domain: "party.edu") }
        let!(:organization_role) { FactoryBot.create(:organization_role_claimed, organization:, user:) }

        it "doesn't offer to set a password" do
          post "/session/sign_in_with_magic_link", params: {token: user.refreshed_magic_link_token}
          expect(flash[:success]).to eq "You're signed in"
          expect(flash[:notice]).to be_blank
        end
      end
    end
  end

  describe "posting with a null origin" do
    include_context :test_csrf_token
    let!(:user) { FactoryBot.create(:user_confirmed) }

    # Privacy extensions and VPNs strip the Origin header, which Rails rejects outright.
    # Losing the session that failed the check is exactly when the form is worth keeping
    it "hands identify back the email it was given" do
      post "/session/identify", params: {session: {email: user.email}}, headers: {"HTTP_ORIGIN" => "null"}
      expect(response).to render_template(:new)
      expect(response.body).to match(user.email)
      expect(flash[:error]).to match(/try again.*a VPN/i)
    end

    it "hands the magic link back its token, unspent" do
      token = user.refreshed_magic_link_token
      post "/session/sign_in_with_magic_link", params: {token:}, headers: {"HTTP_ORIGIN" => "null"}
      expect(response).to render_template(:magic_link)
      expect(user.reload.magic_link_token).to eq token
      expect(Capybara.string(response.body))
        .to have_css("form[action='/session/sign_in_with_magic_link'] input[name='token'][value='#{token}']", visible: :hidden)
    end

    # The retry re-renders without the before_action that stores return_to, so the form
    # is the only thing still holding where the user was headed
    it "hands the magic link back where it was headed" do
      post "/session/sign_in_with_magic_link",
        params: {token: user.refreshed_magic_link_token, return_to: "/oauth/authorize?client_id=xYz"},
        headers: {"HTTP_ORIGIN" => "null"}
      expect(Capybara.string(response.body))
        .to have_css("input[name='return_to'][value='/oauth/authorize?client_id=xYz']", visible: :hidden)
    end
  end

  describe "the return_to carried by the magic link email" do
    let!(:user) { FactoryBot.create(:user_confirmed) }

    # Without clearing the token no second mail is sent within the minute, and the
    # assertion reads the previous one. reload - the token was minted on another copy.
    def emailed_url_after(return_to)
      user.reload.update(magic_link_token: nil)
      get "/session/new?return_to=#{CGI.escape(return_to)}"
      Sidekiq::Testing.inline! { post "/session/create_magic_link", params: {email: user.email} }
      ActionMailer::Base.deliveries.last.body.parts.first.decoded[%r{https?://\S+/session/magic_link\S*}]
    end

    # An off-site target isn't an open redirect - handle_target refuses it on arrival -
    # but it shouldn't reach the mail. "//host" is off-site despite the leading slash.
    it "carries a path this app owns, and drops anything else" do
      expect(emailed_url_after("/bikes/12")).to include CGI.escape("/bikes/12")
      expect(emailed_url_after("https://evil.example/steal")).to_not include "evil.example"
      expect(emailed_url_after("//evil.example/steal")).to_not include "evil.example"
    end
  end

  describe "remember_me across the magic-link round-trip" do
    let!(:user) { FactoryBot.create(:user_confirmed) }
    it "sets a permanent auth cookie when remember_me was chosen at request time" do
      post "/session/create_magic_link", params: {email: user.email, remember_me: "1"}
      token = user.reload.magic_link_token
      expect(token).to be_present
      post "/session/sign_in_with_magic_link", params: {token:}
      expect(auth_set_cookie).to include("expires=")
    end
    it "sets a session auth cookie without remember_me" do
      post "/session/create_magic_link", params: {email: user.email}
      post "/session/sign_in_with_magic_link", params: {token: user.reload.magic_link_token}
      expect(auth_set_cookie).to_not include("expires=")
    end
  end

  describe "create" do
    let(:password) { "example_password2" }
    let!(:user) { FactoryBot.create(:user_confirmed, password: password, password_confirmation: password, banned: banned) }
    let(:banned) { false }
    it "signs in" do
      post "/session", params: {session: {email: user.email, password: password}},
        headers: {"HTTP_CF_CONNECTING_IP" => "66.66.66.66"}
      expect(response).to redirect_to my_account_url
      expect(response.headers["X-Frame-Options"]).to eq "SAMEORIGIN"
      expect(session[:partner]).to be_nil
      user.reload
      expect(signed_auth_cookie[1]).to eq user.auth_token
      expect(user.last_login_at).to be_within(1.second).of Time.current
      expect(user.last_login_ip).to eq "66.66.66.66"
    end
    context "unconfirmed" do
      let(:user) { FactoryBot.create(:user, password: password, password_confirmation: password) }
      it "does not sign in" do
        expect(user.reload.confirmed).to be_falsey
        post "/session", params: {session: {email: user.email, password: password}}
        expect(response).to redirect_to please_confirm_email_users_path
        user.reload
        expect(signed_in_user).to eq user
        expect(user.last_login_at).to be_within(1.second).of Time.current
        get "/my_account"
        expect(response).to redirect_to please_confirm_email_users_path
      end
      context "with a confirmed secondary user_email" do
        let!(:user_email) { FactoryBot.create(:user_email, user:) }
        it "still sends them to please_confirm_email" do
          expect(user_email.confirmed?).to be_truthy
          post "/session", params: {session: {email: user.email, password: password}}
          expect(signed_in_user).to eq user
          expect(response).to redirect_to please_confirm_email_users_path
        end
      end
    end
    context "wrong password" do
      it "stays on the credential step rather than the email step" do
        post "/session", params: {session: {email: user.email, password: "something incorrect"}}
        expect(response).to render_template("identify")
        expect(response).to render_template("layouts/application")
        expect(signed_auth_cookie).to be_nil
      end
    end
    context "email with no account" do
      it "re-renders the email step" do
        post "/session", params: {session: {email: "notThere@example.com"}}
        expect(response).to render_template(:new)
        expect(response).to render_template("layouts/application")
        expect(signed_auth_cookie).to be_nil
      end
    end
    # Prior to #1738 the password minimum was 8 characters - accounts predating it still sign in
    context "password shorter than the current minimum" do
      before { user.update_attribute(:password, "old_pass") }
      it "still signs in" do
        expect(user.reload.authenticate("old_pass")).to be_truthy
        post "/session", params: {session: {email: user.email, password: "old_pass"}},
          headers: {"HTTP_CF_CONNECTING_IP" => "192.168.1.644"}
        expect(response).to redirect_to my_account_url
        expect(signed_in_user).to eq user
        expect(user.reload.last_login_ip).to eq "192.168.1.644"
      end
    end
    context "superuser" do
      let!(:user) { FactoryBot.create(:superuser, password:, password_confirmation: password) }
      it "redirects to admin" do
        post "/session", params: {session: {email: user.email, password:}}
        expect(signed_auth_cookie[1]).to eq user.reload.auth_token
        expect(response).to redirect_to admin_root_url
      end
    end
    context "user is an organization member" do
      let(:organization) { FactoryBot.create(:organization, kind: organization_kind) }
      let(:organization_kind) { "bike_shop" }
      let!(:user) { FactoryBot.create(:organization_user, organization:, password:, password_confirmation: password) }
      it "signs in to the organization" do
        post "/session", params: {session: {email: user.email, password:}}
        expect(signed_auth_cookie[1]).to eq user.reload.auth_token
        expect(session[:render_donation_request]).to be_falsey
        expect(response).to redirect_to organization_root_path(organization_id: organization.to_param)
      end
      context "organization is law_enforcement" do
        let(:organization_kind) { "law_enforcement" }
        it "queues the donation request and sends them to search" do
          post "/session", params: {session: {email: user.email, password:}}
          expect(signed_auth_cookie[1]).to eq user.reload.auth_token
          expect(session[:render_donation_request]).to eq "law_enforcement"
          expect(response).to redirect_to search_registrations_path(stolenness: "all")
        end
      end
    end
    context "partner" do
      include_context :existing_doorkeeper_app
      let!(:user) { FactoryBot.create(:user_confirmed, password:, password_confirmation: password) }
      let(:partner_app) { doorkeeper_app }
      # valid_partner_domain reads a redirect_uri out of the stored return_to and matches it
      # against doorkeeper apps 264 and 356, which the id sequence reaches
      let(:redirect_uri) { nil }
      # Arriving through the partner's OAuth link is what puts partner into the session
      before do
        get "/oauth/authorize", params: {client_id: partner_app.uid, redirect_uri:,
                                         response_type: "code", scope: "read_bikes", partner: "bikehub"}.compact
        expect(session[:partner]).to eq "bikehub"
      end

      it "signs in, returns to the partner and drops the partner session" do
        post "/session", params: {session: {email: user.email, password:}},
          headers: {"HTTP_CF_CONNECTING_IP" => "66.66.66.66"}
        expect(response).to redirect_to "https://parkit.bikehub.com/account?reauthenticate_bike_index=true"
        expect(session[:partner]).to be_nil
        user.reload
        expect(signed_auth_cookie[1]).to eq user.auth_token
        expect(user.last_login_at).to be_within(1.second).of Time.current
        expect(user.last_login_ip).to eq "66.66.66.66"
      end

      context "redirect_uri the bikehub app registered" do
        let(:partner_app) { bikehub_doorkeeper_app }
        let(:redirect_uri) { "https://STAGING.bikehub.com/users/auth/bike_index/callback" }
        it "returns to that subdomain" do
          post "/session", params: {session: {email: user.email, password:}}
          expect(response).to redirect_to "https://staging.bikehub.com/account?reauthenticate_bike_index=true"
          expect(session[:partner]).to be_nil
        end
      end
    end
    context "discourse_redirect stored" do
      before { get "/discourse_authentication?sso=foo&sig=bar" }
      it "redirects to discourse" do
        expect(session[:discourse_redirect]).to eq "sso=foo&sig=bar"
        post "/session", params: {session: {email: user.email, password:}}
        expect(signed_in_user).to eq user
        expect(response).to redirect_to discourse_authentication_url
      end
    end
    context "stored return_to" do
      let(:return_to) { "https://facebook.com/bikeindex" }
      before { get "/session/new", params: {return_to:} }

      it "redirects to it" do
        post "/session", params: {session: {email: user.email, password:}}
        expect(signed_in_user).to eq user
        expect(session[:return_to]).to be_nil
        expect(response).to redirect_to return_to
      end

      context "an oauth authorization url" do
        let(:return_to) { "/oauth/authorize?cool_thing=true" }
        it "redirects to it" do
          post "/session", params: {session: {email: user.email, password:}}
          expect(signed_in_user).to eq user
          expect(session[:return_to]).to be_nil
          expect(response).to redirect_to return_to
        end
      end

      context "a different facebook page" do
        let(:return_to) { "https://facebook.com/bikeindex-mean-place" }
        it "ignores it" do
          post "/session", params: {session: {email: user.email, password:}}
          expect(signed_in_user).to eq user
          expect(session[:return_to]).to be_nil
          expect(response).to redirect_to my_account_url
        end
      end

      context "an off-site url carrying one of ours" do
        let(:return_to) { "http://testhost.com/bad_place?f=/oauth/authorize?cool_thing=true" }
        it "ignores it" do
          post "/session", params: {session: {email: user.email, password:}}
          expect(signed_in_user).to eq user
          expect(session[:return_to]).to be_nil
          expect(response).to redirect_to my_account_url
        end
      end
    end
    describe "secure_headers" do
      it "does not join Set-Cookie headers with newlines" do
        # SecureHeaders::Middleware#flag_cookies! joins cookies with "\n"
        # which Puma 7 rejects as illegal header values.
        # config.cookies = SecureHeaders::OPT_OUT prevents this.
        post "/session", params: {session: {email: user.email, password: password}}
        set_cookie = response.headers["Set-Cookie"]
        expect(set_cookie).to be_present
        expect(set_cookie).not_to include("\n")
      end

      it "includes expected headers" do
        post "/session", params: {session: {email: user.email, password: password}}
        expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
        expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
      end
    end
    context "banned" do
      let(:banned) { true }
      it "renders" do
        post "/session", params: {session: {email: user.email, password: password}}
        expect(response).to redirect_to new_session_path
        user.reload
        expect(user.last_login_at).to be_blank
      end
    end

    # Deleting in admin has to end the session it deletes, not just hide the user from lists
    context "deleted after signing in" do
      it "signs the user out, and won't sign them back in" do
        post "/session", params: {session: {email: user.email, password:}}
        get "/my_account"
        expect(response).to render_template("my_accounts/show")
        user.destroy
        get "/my_account"
        expect(response).to redirect_to new_session_path
        post "/session", params: {session: {email: user.email, password:}}
        expect(response).to render_template(:new)
      end
    end

    context "sso organization email" do
      let(:user) { FactoryBot.create(:user_confirmed, email: "student@sso.edu", password:, password_confirmation: password) }
      let!(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: ["saml_sso"], user_email_domain: "sso.edu")
      end
      let!(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :active, organization:) }
      it "forces SSO instead of accepting the password" do
        post "/session", params: {session: {email: user.email, password:}}
        expect(response).to redirect_to(saml_init_path(org_slug: organization.to_param))
        expect(response.cookies["auth"]).to be_blank
        expect(user.reload.last_login_at).to be_blank
      end
    end

    context "remember_me" do
      it "sets a permanent auth cookie when checked" do
        post "/session", params: {session: {email: user.email, password:, remember_me: "1"}}
        expect(response).to redirect_to my_account_url
        expect(auth_set_cookie).to include("expires=")
      end
      it "sets a session auth cookie when unchecked" do
        post "/session", params: {session: {email: user.email, password:}}
        expect(response).to redirect_to my_account_url
        expect(auth_set_cookie).to_not include("expires=")
      end
      it "preserves the choice on the credential step after a wrong password" do
        post "/session", params: {session: {email: user.email, password: "wrong", remember_me: "1"}}
        expect(response).to render_template(:identify)
        expect(response.body).to include('name="session[remember_me]"')
        expect(response.body).to include('value="1"')
      end
    end

    context "with rack_attack" do
      include_context :rack_attack

      it "returns 429 after exceeding IP limit" do
        # A fresh user per request keeps each email under the per-email
        # throttle, so only the per-IP throttle (retry-after 60) can trip.
        throttled = rack_attack_throttled_response(limit: 10) do
          sign_in_user = FactoryBot.create(:user_confirmed, password:, password_confirmation: password)
          post "/session", params: {session: {email: sign_in_user.email, password:}}
          response
        end
        expect(throttled.headers["retry-after"]).to eq "60"
        expect(throttled.body).to eq "Too Many Requests"
      end

      it "returns 429 after exceeding per-email limit" do
        throttled = rack_attack_throttled_response(limit: 5) do
          post "/session", params: {session: {email: user.email, password:}}
          response
        end
        expect(throttled.headers["retry-after"]).to eq "20"
      end
    end
  end

  describe "destroy" do
    let(:password) { "example_password2" }
    let(:organization) { FactoryBot.create(:organization, kind: "law_enforcement") }
    let!(:user) { FactoryBot.create(:organization_user, organization:, password:, password_confirmation: password) }
    before { post "/session", params: {session: {email: user.email, password:}} }

    it "empties the session and the auth cookie" do
      expect(session[:passive_organization_id]).to eq organization.id
      expect(session.keys).to include("last_seen")

      get "/logout"
      expect(response).to redirect_to goodbye_url
      expect(flash[:notice]).to be_present
      # nothing the signed-in session was holding survives - only the flash it just set
      expect(session.keys).to eq(["flash"])
      expect(response.cookies["auth"]).to be_blank

      get "/my_account"
      expect(response).to redirect_to(/session\/new/)
    end

    context "partner=bikehub" do
      it "redirects to bikehub" do
        get "/logout", params: {partner: "bikehub"}
        expect(response).to redirect_to "https://parkit.bikehub.com/"
        expect(session.keys).to eq([])
        expect(response.cookies["auth"]).to be_blank
      end

      context "with the bikehub doorkeeper app" do
        include_context :existing_doorkeeper_app
        before { expect(bikehub_doorkeeper_app).to be_present }

        it "redirects to a return_to the app registered" do
          get "/logout", params: {partner: "bikehub", return_to: "https://staging.bikehub.com/"}
          expect(response).to redirect_to "https://staging.bikehub.com/"
          expect(session.keys).to eq([])
        end

        context "return_to the app didn't register" do
          it "redirects to parkit" do
            get "/logout", params: {partner: "bikehub", return_to: "https://badplace.stuff.com/"}
            expect(response).to redirect_to "https://parkit.bikehub.com/"
            expect(session.keys).to eq([])
          end
        end
      end
    end

    context "unconfirmed user" do
      let!(:user) { FactoryBot.create(:user, password:, password_confirmation: password) }
      it "logs out the user" do
        get "/logout"
        expect(response).to redirect_to goodbye_url
        expect(session.keys).to eq(["flash"])
        expect(response.cookies["auth"]).to be_blank
      end
    end
  end

  describe "create_magic_link with rack_attack" do
    include_context :rack_attack

    it "returns 429 after exceeding the limit" do
      throttled = rack_attack_throttled_response(limit: 5) do
        post "/session/create_magic_link"
        response
      end
      expect(throttled).to have_http_status(:too_many_requests)
    end
  end
end
