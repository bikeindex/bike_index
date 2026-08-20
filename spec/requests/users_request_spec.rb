require "rails_helper"

RSpec.describe UsersController, type: :request do
  base_url = "/users"

  describe "new" do
    it "renders an email field that offers a correction for a mistyped domain" do
      get "#{base_url}/new"
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
      expect(Capybara.string(response.body)).to have_css("[data-controller='ui--forms--email'] input#user_email")
    end

    context "sso organization domain" do
      let!(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: ["saml_sso"], user_email_domain: "sso.edu")
      end
      let!(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :enabled, organization:) }

      it "hands a claimed email off to the IdP, and renders the form for one it doesn't claim" do
        get "#{base_url}/new", params: {email: "student@sso.edu"}
        expect(response).to redirect_to(saml_init_path(org_slug: organization.to_param))

        get "#{base_url}/new", params: {email: "student@example.edu"}
        expect(response).to render_template(:new)
      end
    end
  end

  describe "create" do
    let(:email) { "ruther99@msu.edu" }

    it "signs up passwordless, links to setting a password once confirmed" do
      expect {
        post base_url, params: {user: {email:, name: "Test name", terms_of_service: "1"}}
      }.to change(User, :count).by(1)
      user = User.order(:created_at).last
      expect(user.passwordless_user?).to be_truthy

      # The emailed link is a GET, so it only renders the form that confirms
      get "#{base_url}/confirm", params: {id: user.id, code: user.confirmation_token}
      expect(response).to render_template(:confirm_interstitial)
      expect(user.reload.confirmed?).to be_falsey
      expect(Capybara.string(response.body))
        .to have_css("form[action='#{base_url}/confirm'] input[name='code'][value='#{user.confirmation_token}']", visible: :hidden)

      post "#{base_url}/confirm", params: {id: user.id, code: user.confirmation_token}
      expect(response).to redirect_to my_account_url
      follow_redirect!
      expect(Capybara.string(response.body))
        .to have_link("set a password to sign in", href: update_password_form_with_reset_token_users_path)
    end

    context "with partner" do
      it "carries the partner through the interstitial" do
        post base_url, params: {user: {email:, name: "Test name", terms_of_service: "1"}, partner: "bikehub"}
        user = User.order(:created_at).last

        get "#{base_url}/confirm", params: {id: user.id, code: user.confirmation_token, partner: "bikehub"}
        expect(Capybara.string(response.body))
          .to have_css("input[name='partner'][value='bikehub']", visible: :hidden)

        post "#{base_url}/confirm", params: {id: user.id, code: user.confirmation_token, partner: "bikehub"}
        expect(response).to redirect_to "https://parkit.bikehub.com/account?reauthenticate_bike_index=true"
      end
    end

    context "sso organization domain" do
      let(:email) { "student@sso.edu" }
      let!(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: ["saml_sso"], user_email_domain: "sso.edu")
      end
      let!(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :enabled, organization:) }

      it "forces SSO instead of creating an account the IdP doesn't know about" do
        expect {
          post base_url, params: {user: {email:, name: "Test name", terms_of_service: "1"}}
        }.to_not change(User, :count)
        expect(response).to redirect_to(saml_init_path(org_slug: organization.to_param))
      end

      context "SAML config not yet live" do
        let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, organization:) }

        it "signs up normally rather than redirecting into an unconfigured IdP" do
          expect {
            post base_url, params: {user: {email:, name: "Test name", terms_of_service: "1"}}
          }.to change(User, :count).by(1)
        end
      end
    end
  end

  describe "create with a null origin" do
    include_context :test_csrf_token
    let(:email) { "ruther99@msu.edu" }

    # Privacy extensions and VPNs strip the Origin header, which Rails rejects outright
    it "re-renders the signup form with the email and an explanation" do
      expect {
        post base_url, params: {user: {email:, password: "somethinggreat", terms_of_service: "1"}},
          headers: {"HTTP_ORIGIN" => "null"}
      }.to_not change(User, :count)
      expect(response).to render_template(:new)
      expect(response.body).to match(email)
      expect(flash[:error]).to match(/try again.*a VPN/i)
      expect(response.body).to match(/try again.*a VPN/i)
    end
  end

  describe "update" do
    include_context :request_spec_logged_in_as_user

    it "updates the terms of service" do
      expect(current_user.reload.address_set_manually).to be_falsey
      put "#{base_url}/#{current_user.username}", params: {id: current_user.username, user: {terms_of_service: "1"}}
      expect(response).to redirect_to(my_account_url)
      expect(current_user.reload.terms_of_service).to be_truthy
      expect(current_user.address_set_manually).to be_falsey
    end

    context "vendor terms" do
      let(:current_user) { FactoryBot.create(:user_confirmed, terms_of_service: false, notification_newsletters: false) }
      it "updates the vendor terms of service and emailable" do
        expect(current_user.reload.notification_newsletters).to be_falsey
        organization = FactoryBot.create(:organization)
        FactoryBot.create(:organization_role_claimed, organization: organization, user: current_user)
        current_user.reload
        expect(OrganizationRole.default_organization(current_user)).to eq organization
        patch "#{base_url}/#{current_user.username}", params: {id: current_user.username, user: {vendor_terms_of_service: "1", notification_newsletters: true}}
        expect(response.code).to eq("302")
        expect(response).to redirect_to organization_root_url(organization_id: organization.to_param)
        expect(current_user.reload.accepted_vendor_terms_of_service?).to be_truthy
        expect(current_user.when_vendor_terms_of_service).to be_within(1.second).of Time.current
        expect(current_user.notification_newsletters).to be_truthy
      end
    end

    describe "submit without updating terms" do
      it "redirects to accept the terms" do
        patch "#{base_url}/#{current_user.id}", params: {id: current_user.username, user: {terms_of_service: "0"}}
        expect(response).to redirect_to accept_terms_path
        expect(current_user.reload.terms_of_service).to be_falsey
      end
      context "vendor_terms" do
        let(:user) { FactoryBot.create(:user_confirmed) }
        it "redirects to accept the terms" do
          expect(current_user.terms_of_service).to be_truthy
          expect(current_user.accepted_vendor_terms_of_service?).to be_falsey
          patch "#{base_url}/#{current_user.username}", params: {id: current_user.username, user: {vendor_terms_of_service: "0"}}
          expect(response).to redirect_to accept_vendor_terms_path
          expect(current_user.reload.vendor_terms_of_service).to be_falsey
        end
      end
    end
  end

  describe "accept_terms" do
    include_context :request_spec_logged_in_as_user
    let(:current_user) { FactoryBot.create(:user_confirmed, terms_of_service: false) }
    it "renders" do
      expect(current_user.reload.terms_of_service).to be_falsey
      expect(current_user.vendor_terms_of_service).to be_falsey
      get "/accept_terms"
      expect(response).to render_template(:accept_terms)
    end

    # Submitting with the box unchecked lands back on the same form, which reads as
    # nothing having happened unless it says what's missing
    it "errors when the terms aren't agreed to" do
      patch "/users/#{current_user.to_param}", params: {user: {terms_of_service: "0"}}

      expect(response).to redirect_to accept_terms_url
      expect(flash[:error]).to eq "You must agree to the terms to use Bike Index"
      expect(flash[:notice]).to be_blank
      expect(current_user.reload.terms_of_service).to be_falsey
    end

    it "accepts them when it is" do
      patch "/users/#{current_user.to_param}", params: {user: {terms_of_service: "1"}}

      expect(response).to redirect_to my_account_url
      expect(flash[:error]).to be_blank
      expect(current_user.reload.terms_of_service).to be_truthy
    end
  end

  describe "accept_vendor_terms" do
    include_context :request_spec_logged_in_as_user
    let(:current_user) { FactoryBot.create(:user_confirmed, vendor_terms_of_service: false) }
    it "renders" do
      expect(current_user.reload.terms_of_service).to be_truthy
      expect(current_user.vendor_terms_of_service).to be_falsey
      get "/accept_vendor_terms"
      expect(response.status).to eq(200)
      expect(response).to render_template(:accept_vendor_terms)
      expect(response).to render_template("layouts/application")
    end
  end

  describe "please_confirm_email" do
    it "renders" do
      get "#{base_url}/please_confirm_email"
      expect(response).to render_template(:please_confirm_email)
      expect(flash).to be_blank
    end
  end

  describe "resend_confirmation_email" do
    it "doesn't send anything if no user found" do
      ActionMailer::Base.deliveries = []
      expect {
        post "#{base_url}/resend_confirmation_email", params: {email: "stuff@stuff.com"}
      }.to_not change(Email::ConfirmationJob, :jobs) # Because it's done inline
      expect(response).to redirect_to please_confirm_email_users_path
      expect(flash[:error]).to be_present
      expect(ActionMailer::Base.deliveries.count).to eq 0
      expect(Notification.count).to eq 0
    end
    context "user present" do
      include_context :request_spec_logged_in_as_user
      let(:current_user) { FactoryBot.create(:user) }

      it "resends the confirmation email" do
        expect(current_user.confirmed?).to be_falsey
        expect(current_user.notifications.count).to eq 0
        ActionMailer::Base.deliveries = []
        expect {
          post "#{base_url}/resend_confirmation_email", params: {email: "blah blah blah"}
        }.to_not change(Email::ConfirmationJob, :jobs) # Because it's done inline
        expect(response).to redirect_to please_confirm_email_users_path
        expect(flash[:success]).to be_present
        expect(ActionMailer::Base.deliveries.count).to eq 1

        # Doing it multiple times doesn't lead to sending multiple notifications
        post "#{base_url}/resend_confirmation_email", params: {email: current_user.email}
        post "#{base_url}/resend_confirmation_email", params: {email: "other stuff"}
        expect(ActionMailer::Base.deliveries.count).to eq 1

        expect(current_user.notifications.count).to eq 1
        expect(current_user.notifications.last.delivery_success?).to be_truthy
        expect(current_user.notifications.last.confirmation_email?).to be_truthy
      end
    end
    context "user found" do
      let!(:user_subject) { FactoryBot.create(:user, email: "test@stuff.com") }
      it "sends email" do
        expect(user_subject.confirmed?).to be_falsey
        expect(user_subject.notifications.count).to eq 0
        ActionMailer::Base.deliveries = []
        expect {
          post "#{base_url}/resend_confirmation_email", params: {email: "test@stuff.com"}
        }.to_not change(Email::ConfirmationJob, :jobs) # Because it's done inline
        expect(response).to redirect_to please_confirm_email_users_path
        expect(flash[:success]).to be_present
        expect(ActionMailer::Base.deliveries.count).to eq 1

        # Doing it multiple times doesn't lead to sending multiple notifications
        post "#{base_url}/resend_confirmation_email", params: {email: "test@stuff.com"}
        expect(ActionMailer::Base.deliveries.count).to eq 1

        expect(user_subject.notifications.count).to eq 1
        expect(user_subject.notifications.last.delivery_success?).to be_truthy
        expect(user_subject.notifications.last.confirmation_email?).to be_truthy
      end
      context "user confirmed" do
        let!(:user_subject) { FactoryBot.create(:user_confirmed, email: "test@stuff.com") }
        it "does not send a notification" do
          expect(user_subject.confirmed?).to be_truthy
          ActionMailer::Base.deliveries = []
          expect {
            post "#{base_url}/resend_confirmation_email", params: {email: "test@stuff.com"}
          }.to_not change(Email::ConfirmationJob, :jobs) # Because it's done inline
          expect(response).to redirect_to please_confirm_email_users_path
          expect(flash[:error]).to be_present
          expect(ActionMailer::Base.deliveries.count).to eq 0
          expect(Notification.count).to eq 0
        end
      end
    end
  end

  describe "resend_confirmation_email with rack_attack" do
    include_context :rack_attack

    it "returns 429 after exceeding the limit" do
      throttled = rack_attack_throttled_response(limit: 5) do
        post "#{base_url}/resend_confirmation_email", params: {email: "a@b.com"}
        response
      end
      expect(throttled).to have_http_status(:too_many_requests)
    end
  end

  describe "send_password_reset_email with rack_attack" do
    include_context :rack_attack

    it "returns 429 after exceeding the limit" do
      throttled = rack_attack_throttled_response(limit: 5) do
        post "#{base_url}/send_password_reset_email", params: {email: "a@b.com"}
        response
      end
      expect(throttled).to have_http_status(:too_many_requests)
    end
  end

  describe "request_password_reset_form" do
    it "renders" do
      get "#{base_url}/request_password_reset_form"
      expect(response.code).to eq("200")
      expect(response).to render_template(:request_password_reset_form)
    end
  end

  describe "send_password_reset_email" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    it "enqueues a password reset email job" do
      expect(user.token_for_password_reset).to be_blank
      ActionMailer::Base.deliveries = []
      Sidekiq::Job.clear_all
      Sidekiq::Testing.inline! do
        post "#{base_url}/send_password_reset_email", params: {email: user.email}
        expect(response.code).to eq("200")
        expect(response).to render_template(:send_password_reset_email)
        expect(flash).to be_blank
      end
      expect(ActionMailer::Base.deliveries.count).to eq 1
      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq("Instructions to reset your password")

      user.reload
      expect(user.token_for_password_reset).to be_present
    end
    context "unknown user" do
      it "redirects back and flash errors if unable to find user" do
        expect {
          post "#{base_url}/send_password_reset_email", params: {email: "some-crazy-email@stuff.com"}
        }.to_not change(Email::ResetPasswordJob.jobs, :size)
        expect(flash[:error]).to match(/email/)
        expect(response).to redirect_to request_password_reset_form_users_path
      end
    end
    context "secondary email" do
      let!(:user_email) { FactoryBot.create(:user_email, user: user) }
      it "enqueues a password reset email job" do
        expect {
          post "#{base_url}/send_password_reset_email", params: {email: user_email.email}
          expect(response.code).to eq("200")
          expect(response).to render_template(:send_password_reset_email)
          expect(flash).to be_blank
        }.to change(Email::ResetPasswordJob.jobs, :size).by(1)
        expect(Email::ResetPasswordJob).to have_enqueued_sidekiq_job(user.id)
        user.reload
        expect(user.token_for_password_reset).to be_present
      end
    end
    context "unconfirmed user" do
      let(:user) { FactoryBot.create(:user) }
      it "enqueues a password reset email job" do
        expect(user.confirmed?).to be_falsey
        expect {
          post "#{base_url}/send_password_reset_email", params: {email: user.email}
          expect(response.code).to eq("200")
          expect(response).to render_template(:send_password_reset_email)
          expect(flash).to be_blank
        }.to change(Email::ResetPasswordJob.jobs, :size).by(1)
        user.reload
        expect(user.token_for_password_reset).to be_present
        expect(user.confirmed?).to be_falsey
      end
    end
    context "banned user" do
      let(:user) { FactoryBot.create(:user_confirmed, banned: true) }

      it "enqueues a password reset email job" do
        expect(user.reload.banned?).to be_truthy
        expect {
          post "#{base_url}/send_password_reset_email", params: {email: user.email}
          expect(response.code).to eq("200")
          expect(response).to render_template(:send_password_reset_email)
          expect(flash).to be_blank
        }.to change(Email::ResetPasswordJob.jobs, :size).by(1)
        user.reload
        expect(user.token_for_password_reset).to be_present
      end
    end
    context "existing password reset token" do
      it "does not resend if just sent" do
        user.send_password_reset_email
        og_token = user.token_for_password_reset
        expect {
          post "#{base_url}/send_password_reset_email", params: {email: user.email}
          expect(response.code).to eq("200")
          expect(response).to render_template(:send_password_reset_email)
          expect(flash).to be_present
        }.to_not change(Email::ResetPasswordJob.jobs, :size)
        user.reload
        expect(user.token_for_password_reset).to eq og_token
      end
      context "older token" do
        it "updates token and sends" do
          user.update_auth_token("token_for_password_reset", Time.current - 5.minutes)
          og_token = user.token_for_password_reset
          expect(og_token).to be_present
          expect {
            post "#{base_url}/send_password_reset_email", params: {email: user.email}
            expect(response.code).to eq("200")
            expect(response).to render_template(:send_password_reset_email)
            expect(flash).to be_blank
          }.to change(Email::ResetPasswordJob.jobs, :size).by(1)
          user.reload
          expect(user.token_for_password_reset).to_not eq og_token
        end
      end
    end
  end

  describe "update_password_form_with_reset_token" do
    let(:user) { FactoryBot.create(:user) }
    it "renders" do
      user.send_password_reset_email
      og_token = user.token_for_password_reset
      get "#{base_url}/update_password_form_with_reset_token?token=#{og_token}"
      expect(response.code).to eq("200")
      expect(response).to render_template(:update_password_form_with_reset_token)
      expect(flash).to be_blank
      user.reload
      expect(user.token_for_password_reset).to eq og_token
    end
    context "nil token" do
      it "redirects" do
        expect(user.token_for_password_reset).to be_blank # technically, this matches the pasesd token
        get "#{base_url}/update_password_form_with_reset_token", params: {token: ""}
        expect(response).to redirect_to request_password_reset_form_users_path
        expect(flash[:error]).to be_present
      end
      context "signed in" do
        include_context :request_spec_logged_in_as_user
        let(:current_user) { FactoryBot.create(:user_confirmed, passwordless_user: true) }
        it "renders without emailing a reset token" do
          get "#{base_url}/update_password_form_with_reset_token"
          expect(response.code).to eq("200")
          expect(response).to render_template(:update_password_form_with_reset_token)
          expect(flash).to be_blank
          expect(current_user.reload.token_for_password_reset).to be_blank
        end
      end
    end
    context "token not found" do
      it "redirects" do
        get "#{base_url}/update_password_form_with_reset_token", params: {token: "uopfqwenafcvxcvasdf"}
        expect(response).to redirect_to request_password_reset_form_users_path
        expect(flash[:error]).to be_present
      end
    end
    context "auth token expired" do
      it "redirects" do
        user.update_auth_token("token_for_password_reset", (User::AUTH_TOKEN_EXPIRY + 1.minute).ago)
        og_token = user.token_for_password_reset
        get "#{base_url}/update_password_form_with_reset_token", params: {token: user.token_for_password_reset}
        expect(response).to redirect_to request_password_reset_form_users_path
        expect(flash[:error]).to match "expired"
        user.reload
        expect(user.token_for_password_reset).to eq og_token
      end
    end
  end

  describe "update_password_with_reset_token" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:valid_params) do
      {
        token: user.token_for_password_reset,
        user: {password: "b79xzcvb9xcvbzaxcvvvcvqwerwe7823412/`!", password_confirmation: "b79xzcvb9xcvbzaxcvvvcvqwerwe7823412/`!"}
      }
    end
    it "updates user and signs in" do
      user.send_password_reset_email
      og_auth = user.auth_token
      og_token = user.token_for_password_reset
      post "#{base_url}/update_password_with_reset_token", params: valid_params
      expect(response).to redirect_to my_account_url
      # Signing in doesn't replace it with the generic "Logged in!"
      expect(flash[:success]).to match(/password reset successfully/i)
      user.reload
      expect(user.token_for_password_reset).to_not eq og_token
      expect(user.auth_token).to_not eq og_auth
      expect(user.authenticate(valid_params.dig(:user, :password))).to be_truthy
      jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
      expect(jar.signed["auth"]).to eq([user.id, user.auth_token])
    end
    context "unconfirmed user" do
      let(:user) { FactoryBot.create(:user) }
      it "confirms user and signs in" do
        user.send_password_reset_email
        user.reload
        og_auth = user.auth_token
        og_token = user.token_for_password_reset
        expect(user.confirmed?).to be_falsey
        post "#{base_url}/update_password_with_reset_token", params: valid_params
        expect(response).to redirect_to my_account_url
        user.reload
        expect(user.token_for_password_reset).to_not eq og_token
        expect(user.auth_token).to_not eq og_auth
        expect(user.authenticate(valid_params.dig(:user, :password))).to be_truthy
        jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
        expect(jar.signed["auth"]).to eq([user.id, user.auth_token])
        expect(user.confirmed?).to be_truthy
      end
    end
    context "user who hasn't accepted terms" do
      let(:user) { FactoryBot.create(:user_confirmed, terms_of_service: false) }
      it "redirects to terms" do
        user.send_password_reset_email
        user.reload
        og_token = user.token_for_password_reset
        expect(user.confirmed?).to be_truthy
        expect(user.terms_of_service).to be_falsey
        post "#{base_url}/update_password_with_reset_token", params: valid_params
        # It redirects to account - but when rendering account, redirects to accept terms - tested below
        expect(response).to redirect_to my_account_url
        get "/my_account"
        expect(response).to redirect_to accept_terms_url
        user.reload
        expect(user.token_for_password_reset).to_not eq og_token
        expect(user.authenticate(valid_params.dig(:user, :password))).to be_truthy
        jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
        expect(jar.signed["auth"]).to eq([user.id, user.auth_token])
        expect(user.confirmed?).to be_truthy
        expect(user.terms_of_service).to be_falsey
      end
    end
    context "invalid password" do
      let(:invalid_params) { valid_params.merge(user: {password: "Too-sh0rt", password_confirmation: "Too-sh0rt"}) }
      it "redirects back, doesn't sign in" do
        user.send_password_reset_email
        og_auth = user.auth_token
        og_token = user.token_for_password_reset
        post "#{base_url}/update_password_with_reset_token", params: invalid_params
        expect(assigns(:page_errors)).to be_present
        expect(response).to render_template(:update_password_form_with_reset_token)
        user.reload
        expect(user.token_for_password_reset).to eq og_token
        expect(user.auth_token).to eq og_auth
        expect(user.authenticate(valid_params.dig(:user, :password))).to be_falsey
        expect(response.cookies[:auth]).to be_blank
      end
    end
    context "incorrect password_confirmation" do
      let(:invalid_params) { valid_params.merge(user: {password: "validvalidvalid", password_confirmation: "invalidvalidvalid"}) }
      it "redirects back, doesn't sign in" do
        user.send_password_reset_email
        og_token = user.token_for_password_reset
        post "#{base_url}/update_password_with_reset_token", params: invalid_params
        expect(assigns(:page_errors)).to be_present
        expect(response).to render_template(:update_password_form_with_reset_token)
        user.reload
        expect(user.token_for_password_reset).to eq og_token
        expect(user.authenticate(valid_params.dig(:user, :password))).to be_falsey
        expect(response.cookies[:auth]).to be_blank
      end
    end
    context "signed in passwordless user" do
      include_context :request_spec_logged_in_as_user
      let(:current_user) { FactoryBot.create(:user_confirmed, passwordless_user: true) }
      it "sets the password without a token" do
        post "#{base_url}/update_password_with_reset_token", params: valid_params.merge(token: "")
        expect(response).to redirect_to my_account_url
        current_user.reload
        expect(current_user.passwordless_user?).to be_falsey
        expect(current_user.authenticate(valid_params.dig(:user, :password))).to be_truthy
      end
    end
    context "nil token" do
      it "redirects" do
        user.reload
        expect(user.token_for_password_reset).to be_blank
        post "#{base_url}/update_password_with_reset_token", params: valid_params.merge(token: "")
        expect(response).to redirect_to request_password_reset_form_users_path
        expect(flash[:error]).to be_present
        user.reload
        expect(user.authenticate(valid_params.dig(:user, :password))).to be_falsey
        expect(response.cookies[:auth]).to be_blank
      end
    end
    context "token not found" do
      it "redirects" do
        post "#{base_url}/update_password_with_reset_token", params: valid_params.merge(token: "uopfqwenafcvxcvasdf")
        expect(response).to redirect_to request_password_reset_form_users_path
        expect(flash[:error]).to match("match")
        expect(response.cookies[:auth]).to be_blank
      end
    end
    context "auth token expired" do
      it "redirects" do
        user.update_auth_token("token_for_password_reset", (User::AUTH_TOKEN_EXPIRY + 1.minute).ago)
        user.reload
        og_token = user.token_for_password_reset
        post "#{base_url}/update_password_with_reset_token", params: valid_params
        expect(response).to redirect_to request_password_reset_form_users_path
        expect(flash[:error]).to match "expired"
        user.reload
        expect(user.token_for_password_reset).to eq og_token
        expect(user.authenticate(valid_params.dig(:user, :password))).to be_falsey
        expect(response.cookies[:auth]).to be_blank
      end
    end
  end

  describe "show" do
    let(:user) { FactoryBot.create(:user_confirmed, show_bikes:) }
    let(:show_bikes) { false }

    it "404s if the user doesn't exist" do
      get "#{base_url}/fake_user-extra-stuff"
      expect(response.status).to eq 404
    end

    context "user doesn't show their page" do
      it "redirects to user home url" do
        get "#{base_url}/#{user.username}"
        expect(response).to redirect_to my_account_url
      end
    end

    context "owner viewing their own hidden page" do
      include_context :request_spec_logged_in_as_user
      let(:current_user) { FactoryBot.create(:user_confirmed, show_bikes: false) }

      it "renders with a notice that only they can see it" do
        get "#{base_url}/#{current_user.username}"
        expect(response.status).to eq 200
        expect(response).to render_template :show
        expect(assigns(:profile_hidden_reason)).to eq :owner
        expect(response.body).to match(/only visible to you/i)
      end
    end

    context "user shows their page" do
      let(:show_bikes) { true }

      it "renders" do
        get "#{base_url}/#{user.username}?page=1&per_page=1"
        expect(response).to render_template :show
        expect(assigns(:per_page)).to eq 1
        # Test some header tag properties
        expect(response.body).to match(/<title>#{user.name}</)
      end

      context "banned user" do
        let(:user) { FactoryBot.create(:user_confirmed, show_bikes:, banned: true) }
        it "404s" do
          get "#{base_url}/#{user.username}"
          expect(response.status).to eq 404
        end
      end

      context "email banned user" do
        let!(:email_ban) { FactoryBot.create(:email_ban, user:) }
        it "404s" do
          expect(user.reload.email_banned?).to be_truthy
          get "#{base_url}/#{user.username}"
          expect(response.status).to eq 404
        end
      end
    end

    context "superuser viewing a banned user" do
      include_context :request_spec_logged_in_as_superuser
      let(:user) { FactoryBot.create(:user_confirmed, show_bikes:, banned: true) }

      it "renders the profile with a banned alert" do
        get "#{base_url}/#{user.username}"
        expect(response.status).to eq 200
        expect(response).to render_template :show
        expect(assigns(:user_banned)).to be_truthy
        expect(response.body).to match(/is banned/)
      end
    end

    context "superuser viewing a hidden unbanned user" do
      include_context :request_spec_logged_in_as_superuser

      it "renders with a notice that only a superuser can see it" do
        get "#{base_url}/#{user.username}"
        expect(response.status).to eq 200
        expect(assigns(:profile_hidden_reason)).to eq :superuser
        expect(response.body).to match(/only visible because you/i)
      end
    end
  end

  describe "unsubscribe" do
    let!(:user) { FactoryBot.create(:user_confirmed, notification_newsletters: true) }
    let(:signed_id) { user.unsubscribe_signed_id }

    it "renders" do
      expect(user.notification_newsletters).to be_truthy
      get "#{base_url}/#{signed_id}/unsubscribe"
      expect(assigns(:user)&.id).to eq user.id
      expect(response.code).to eq("200")
      expect(response).to render_template("users/unsubscribe")
      # The rendered interstitial posts to unsubscribe_update, it doesn't unsubscribe here
      expect(Capybara.string(response.body))
        .to have_css("form[action^='#{base_url}/'][action$='/unsubscribe_update']")
      expect(flash).to be_blank
      expect(user.reload.notification_newsletters).to be_truthy
    end

    context "current_user" do
      include_context :request_spec_logged_in_as_user
      let(:current_user) { FactoryBot.create(:user_confirmed, notification_newsletters: true) }
      it "renders current user instead" do
        expect(current_user.notification_newsletters).to be_truthy
        get "#{base_url}/#{signed_id}/unsubscribe"
        expect(assigns(:user)&.id).to eq current_user.id
        expect(response.code).to eq("200")
        expect(response).to render_template("users/unsubscribe")
        expect(flash).to be_blank
        expect(user.reload.notification_newsletters).to be_truthy
        expect(current_user.reload.notification_newsletters).to be_truthy
      end
    end

    context "with plain username" do
      it "redirects (does not find user, prevents enumeration)" do
        get "#{base_url}/#{user.username}/unsubscribe"
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
      end
    end

    context "with invalid token" do
      it "redirects (does not find user, prevents enumeration)" do
        get "#{base_url}/cvxvxxxxx/unsubscribe"
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
      end
    end

    context "user already unsubscribed" do
      let(:user) { FactoryBot.create(:user_confirmed, notification_newsletters: false) }
      it "renders" do
        expect(user.notification_newsletters).to be_falsey
        get "#{base_url}/#{signed_id}/unsubscribe"
        expect(assigns(:user)&.id).to eq user.id
        expect(response.code).to eq("200")
        expect(response).to render_template("users/unsubscribe")
        expect(flash).to be_blank
        expect(user.reload.notification_newsletters).to be_falsey
      end
    end
  end

  describe "unsubscribe_update" do
    let!(:user) { FactoryBot.create(:user_confirmed, notification_newsletters: true) }
    let(:signed_id) { user.unsubscribe_signed_id }

    it "unsubscribes" do
      expect(user.notification_newsletters).to be_truthy
      post "#{base_url}/#{signed_id}/unsubscribe_update"
      expect(response.code).to eq("302")
      expect(flash[:success]).to be_present
      expect(user.reload.notification_newsletters).to be_falsey
    end

    context "current_user" do
      include_context :request_spec_logged_in_as_user
      let(:current_user) { FactoryBot.create(:user_confirmed, notification_newsletters: true) }
      it "unsubscribes the signed id's user, not the session's" do
        expect(current_user.notification_newsletters).to be_truthy
        post "#{base_url}/#{signed_id}/unsubscribe_update"
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
        expect(user.reload.notification_newsletters).to be_falsey
        expect(current_user.reload.notification_newsletters).to be_truthy
      end
    end

    # RFC 8058 - the mail client's own unsubscribe button
    context "one-click" do
      include_context :test_csrf_token
      it "unsubscribes without a session or a CSRF token" do
        post "#{base_url}/#{signed_id}/unsubscribe_update", params: {"List-Unsubscribe" => "One-Click"}
        expect(response.code).to eq("200")
        expect(response.body).to be_blank
        expect(user.reload.notification_newsletters).to be_falsey
      end
    end

    # A mail client that doesn't do one-click opens the POST target in a browser
    it "GET renders the interstitial rather than unsubscribing" do
      get "#{base_url}/#{signed_id}/unsubscribe_update"
      expect(response.code).to eq("200")
      expect(response).to render_template("users/unsubscribe")
      expect(user.reload.notification_newsletters).to be_truthy
    end

    context "with plain username" do
      it "does not unsubscribe (token required)" do
        post "#{base_url}/#{user.username}/unsubscribe_update"
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
        expect(user.reload.notification_newsletters).to be_truthy
      end
    end

    context "with invalid token" do
      it "does not error, shows same flash success (to prevent email enumeration)" do
        post "#{base_url}/cvxvxxxxx/unsubscribe_update"
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
      end
    end

    context "user already unsubscribed" do
      let(:user) { FactoryBot.create(:user_confirmed, notification_newsletters: false) }
      it "does nothing" do
        expect(user.notification_newsletters).to be_falsey
        post "#{base_url}/#{signed_id}/unsubscribe_update"
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
        expect(user.reload.notification_newsletters).to be_falsey
      end
    end
  end
end
