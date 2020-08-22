require "rails_helper"

RSpec.describe UsersController, type: :controller do
  let(:user) { FactoryBot.create(:user_confirmed) }
  describe "new" do
    context "already signed in" do
      include_context :logged_in_as_user
      it "redirects and sets the flash" do
        get :new
        expect(response).to redirect_to(:my_account)
        expect(flash).to be_present
      end
      context "return_to" do
        it "redirects to return_to" do
          get :new, params: {return_to: "/bikes/12?contact_owner=true"}
          expect(response).to redirect_to "/bikes/12?contact_owner=true"
        end
      end
      context "unconfirmed" do
        let(:user) { FactoryBot.create(:user) }
        it "redirects to please_confirm_email" do
          get :new, params: {return_to: "/bikes/12?contact_owner=true"}
          expect(response).to redirect_to please_confirm_email_users_path
          expect(session[:return_to]).to eq "/bikes/12?contact_owner=true"
        end
      end
    end
    context "not signed in" do
      it "renders" do
        get :new
        expect(response.code).to eq("200")
        expect(response).to render_template("new")
        expect(flash).to_not be_present
        expect(response).to render_template("layouts/application")
      end
      context "with partner param" do
        it "actually sets it" do
          get :new, params: {email: "seth@bikes.com", return_to: "/bikes/12?contact_owner=true", partner: "bikehub"}
          expect(assigns(:user).email).to eq "seth@bikes.com"
          expect(session[:return_to]).to eq "/bikes/12?contact_owner=true"
          expect(session[:partner]).to be_nil
          expect(response).to render_template("layouts/application_bikehub")
        end
        context "with partner session" do
          it "actually sets it" do
            session[:partner] = "bikehub"
            get :new, params: {return_to: "/bikes/12?contact_owner=true"}
            expect(session[:return_to]).to eq "/bikes/12?contact_owner=true"
            session[:partner] = "bikehub"
            expect(response).to render_template("layouts/application_bikehub")
          end
        end
      end
    end
  end

  describe "please_confirm_email" do
    it "renders (without a user)" do
      get :please_confirm_email
      expect(response.code).to eq("200")
      expect(response).to render_template("please_confirm_email")
      expect(flash).to_not be_present
    end
    context "with user" do
      include_context :logged_in_as_user
      it "redirects to user_home" do
        get :please_confirm_email
        expect(response).to redirect_to my_account_path
      end
      context "unconfirmed user" do
        let(:user) { FactoryBot.create(:user) }
        it "renders" do
          get :please_confirm_email
          expect(response.code).to eq("200")
          expect(response).to render_template("please_confirm_email")
          expect(flash).to_not be_present
        end
      end
    end
  end

  describe "create" do
    let(:user_attributes) do
      {
        name: "Test name",
        email: "poo@pile.com",
        password: "testthisthing7$",
        password_confirmation: "testthisthing7$",
        terms_of_service: true
      }
    end
    describe "success" do
      it "creates a non-confirmed record, doesn't block on unknown language" do
        expect {
          post :create, params: {locale: "klingon", user: user_attributes}
        }.to change(User, :count).by(1)
        expect(flash).to_not be_present
        expect(response).to redirect_to(please_confirm_email_users_path)
        user = User.order(:created_at).last
        expect(User.from_auth(cookies.signed[:auth])).to eq user
        expect(user.partner_sign_up).to be_nil
        expect(user.partner_sign_up).to be_nil
        expect(user.unconfirmed?).to be_truthy
        expect(user.preferred_language).to be_blank # Because language wasn't passed
      end
      context "with locale passed" do
        it "creates a user with a preferred_language" do
          request.env["HTTP_CF_CONNECTING_IP"] = "99.99.99.9"
          Sidekiq::Worker.clear_all
          expect {
            post :create, params: {locale: "nl", user: user_attributes}
          }.to change(EmailConfirmationWorker.jobs, :count).by 1

          user = User.order(:created_at).last
          expect(User.from_auth(cookies.signed[:auth])).to eq user
          expect(user.partner_sign_up).to be_nil
          expect(user.unconfirmed?).to be_truthy
          expect(user.last_login_at).to be_within(3.seconds).of Time.current
          expect(user.last_login_ip).to eq "99.99.99.9"
          expect(user.preferred_language).to eq "nl"
          expect(flash).to_not be_present
          expect(response).to redirect_to(please_confirm_email_users_path)

          ActionMailer::Base.deliveries = []
          expect {
            EmailConfirmationWorker.drain
          }.to change(ActionMailer::Base.deliveries, :count).by 1

          mail = ActionMailer::Base.deliveries.last
          expect(mail.subject).to eq("Bevestig uw e-mail met Bike Index!")
          expect(mail.to).to eq([user.email])
          expect(mail.from).to eq(["contact@bikeindex.org"])
        end
      end
      context "with membership and an example bike" do
        let(:email) { "test@stuff.com" }
        let(:membership) { FactoryBot.create(:membership, invited_email: " #{email.upcase}", role: "member") }
        let!(:organization) { membership.organization }
        let(:bike) { FactoryBot.create(:bike, example: true, owner_email: email) }
        let!(:ownership) { FactoryBot.create(:ownership, bike: bike, owner_email: email) }
        let(:user_attributes) { {email: email, name: "SAMPLE", password: "pleaseplease12", terms_of_service: "1", notification_newsletters: "0"} }

        it "creates a confirmed user, logs in, and send welcome even with an example bike" do
          expect(session[:passive_organization_id]).to be_blank
          bike.reload
          expect(bike.user).to be_blank
          Sidekiq::Worker.clear_all
          expect {
            request.env["HTTP_CF_CONNECTING_IP"] = "99.99.99.9"
            post :create, params: {user: user_attributes}
            user = User.where(email: email).first
            expect(response).to redirect_to organization_root_path(organization_id: organization.to_param)
            expect(session[:passive_organization_id]).to eq organization.id
            expect(user.terms_of_service).to be_truthy
            expect(user.email).to eq email
            expect(User.from_auth(cookies.signed[:auth])).to eq user
            expect(user.confirmed?).to be_truthy
            expect(user.last_login_at).to be_within(3.seconds).of Time.current
            expect(user.last_login_ip).to eq "99.99.99.9"
            expect(user.preferred_language).to be_blank # Because language wasn't passed
            expect(user.user_emails.count).to eq 1
            expect(user.user_emails.first.email).to eq email
            expect(User.fuzzy_email_find(email)).to eq user
            # bike association is processed async, so we have to drain the queue
            expect(AfterUserCreateWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([user.id, "async"])
            AfterUserCreateWorker.drain
            bike.reload
            expect(bike.user).to eq user
          }.to change(EmailWelcomeWorker.jobs, :count)
        end
      end
      context "with membership, partner param" do
        let!(:membership) { FactoryBot.create(:membership, invited_email: "poo@pile.com") }
        it "creates a confirmed user, log in, and send welcome, language header" do
          session[:passive_organization_id] = "0"
          request.env["HTTP_ACCEPT_LANGUAGE"] = "nl,en;q=0.9"
          allow(EmailWelcomeWorker).to receive(:perform_async)

          post :create, params: {user: user_attributes, partner: "bikehub"}

          expect(response).to redirect_to("https://parkit.bikehub.com/account?reauthenticate_bike_index=true")
          user = User.find_by_email("poo@pile.com")
          expect(EmailWelcomeWorker).to have_received(:perform_async).with(user.id)
          expect(user.partner_sign_up).to eq "bikehub"
          expect(user.email).to eq "poo@pile.com"

          expect(User.from_auth(cookies.signed[:auth])).to eq user
          expect(user.last_login_at).to be_within(2.seconds).of Time.current
          expect(user.preferred_language).to eq "nl"
          expect(session[:passive_organization_id]).to eq membership.organization_id
        end
      end
      context "with partner session" do
        it "renders parter sign in page" do
          session[:partner] = "bikehub"
          expect {
            post :create, params: {user: user_attributes}
          }.to change(User, :count).by(1)
          expect(flash).to_not be_present
          expect(response).to redirect_to("https://parkit.bikehub.com/account?reauthenticate_bike_index=true")
          expect(session[:partner]).to be_nil
          user = User.order(:created_at).last
          expect(user.email).to eq(user_attributes[:email])
          expect(user.partner_sign_up).to eq "bikehub"
          expect(user.partner_data).to eq({sign_up: "bikehub"}.as_json)
          expect(User.from_auth(cookies.signed[:auth])).to eq user
        end
      end
      context "with auto passwordless users" do
        let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["passwordless_users"], passwordless_user_domain: "ladot.online", available_invitation_count: 1) }
        let(:email) { "example@ladot.online" }
        it "Does not create a membership or automatically confirm the user" do
          expect(session[:passive_organization_id]).to be_blank
          ActionMailer::Base.deliveries = []
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! do
            request.env["HTTP_CF_CONNECTING_IP"] = "169.99.69.2"
            expect {
              post :create, params: {user: user_attributes.merge(email: email)}
            }.to change(User, :count).by 1

            user = User.where(email: email).first
            expect(flash).to_not be_present
            expect(response).to redirect_to(please_confirm_email_users_path)

            expect(user.terms_of_service).to be_truthy
            expect(User.from_auth(cookies.signed[:auth])).to eq user
            expect(user.confirmed?).to be_falsey
            expect(user.last_login_at).to be_within(3.seconds).of Time.current
            expect(user.last_login_ip).to eq "169.99.69.2"
            expect(user.preferred_language).to be_blank # Because language wasn't passed
            expect(user.user_emails.count).to eq 0
          end

          expect(ActionMailer::Base.deliveries.count).to eq 1
          mail = ActionMailer::Base.deliveries.last
          expect(mail.subject).to eq("Please confirm your Bike Index email!")
          expect(mail.to).to eq([email])
          expect(mail.from).to eq(["contact@bikeindex.org"])
        end
      end
    end

    describe "failure" do
      let(:user_attributes) do
        user = FactoryBot.attributes_for(:user)
        user[:password_confirmation] = "bazoo"
        user
      end
      it "does not create a user or send a welcome email" do
        expect {
          expect {
            post :create, params: {user: user_attributes}
          }.to_not change(EmailWelcomeWorker.jobs, :count)
        }.to_not change(User, :count)
      end
      context "partner param" do
        it "renders new" do
          post :create, params: {partner: "bikehub", user: user_attributes}
          expect(response).to render_template("new")
          expect(assigns(:page_errors)).to be_present
          expect(response).to render_template("layouts/application_bikehub")
        end
      end
    end
  end

  describe "confirm" do
    describe "user exists" do
      it "tells the user to log in when already confirmed" do
        get :confirm, params: {id: user.id, code: "wtfmate"}
        expect(response).to redirect_to new_session_url
      end

      describe "user not yet confirmed" do
        let!(:user) { FactoryBot.create(:user) }

        it "logins and redirect when confirmation succeeds" do
          get :confirm, params: {id: user.id, code: user.confirmation_token}
          expect(User.from_auth(cookies.signed[:auth])).to eq(user)
          expect(response).to redirect_to my_account_url
          expect(session[:partner]).to be_nil
        end

        context "with partner" do
          it "logins and redirect when confirmation succeeds" do
            get :confirm, params: {id: user.id, code: user.confirmation_token, partner: "bikehub"}
            expect(User.from_auth(cookies.signed[:auth])).to eq(user)
            expect(response).to redirect_to "https://parkit.bikehub.com/account?reauthenticate_bike_index=true"
            expect(session[:partner]).to be_nil
          end
          context "in session" do
            it "logins and redirect when confirmation succeeds" do
              session[:partner] = "bikehub"
              get :confirm, params: {id: user.id, code: user.confirmation_token}
              expect(User.from_auth(cookies.signed[:auth])).to eq(user)
              expect(response).to redirect_to "https://parkit.bikehub.com/account?reauthenticate_bike_index=true"
              expect(session[:partner]).to be_nil
            end
          end
          context "user signed in" do
            it "redirects" do
              expect(user.confirmed?).to be_falsey
              set_current_user(user)
              get :confirm, params: {id: user.id, code: user.confirmation_token, partner: "bikehub"}
              user.reload
              expect(User.from_auth(cookies.signed[:auth])).to eq(user)
              expect(response).to redirect_to "https://parkit.bikehub.com/account?reauthenticate_bike_index=true"
              expect(session[:partner]).to be_nil
              expect(user.confirmed?).to be_truthy
            end
          end
        end

        it "shows a view when confirmation fails" do
          get :confirm, params: {id: user.id, code: "Wtfmate"}
          expect(response).to render_template :confirm_error_bad_token
        end
      end

      context "with auto_passwordless organization" do
        let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["passwordless_users"], passwordless_user_domain: "ladot.online", available_invitation_count: 1) }
        let(:user) { FactoryBot.create(:user, email: email) }
        let(:email) { "something@ladot.com" }

        def expect_confirmed_and_set_ip(user)
          user.reload
          expect(User.from_auth(cookies.signed[:auth])).to eq(user)
          expect(user.confirmed?).to be_truthy
          expect(user.last_login_at).to be_within(3.seconds).of Time.current
          expect(user.last_login_ip).to eq "169.99.69.2"
        end

        it "logins and redirects when confirmation succeeds, doesn't associate" do
          request.env["HTTP_CF_CONNECTING_IP"] = "169.99.69.2"
          user.reload
          expect(user.confirmed?).to be_falsey
          get :confirm, params: {id: user.id, code: user.confirmation_token}
          expect(response).to redirect_to my_account_url
          expect(session[:partner]).to be_nil
          expect_confirmed_and_set_ip(user)
          expect(user.memberships.count).to eq 0
          expect(session[:passive_organization_id]).to eq "0"
        end
        context "domain matching" do
          let(:email) { "something@ladot.online" }
          it "logins and redirects when confirmation succeeds" do
            request.env["HTTP_CF_CONNECTING_IP"] = "169.99.69.2"
            expect(user.confirmed?).to be_falsey
            expect(session[:passive_organization_id]).to be_blank
            get :confirm, params: {id: user.id, code: user.confirmation_token}
            expect(response).to redirect_to organization_root_path(organization_id: organization.to_param)
            expect(session[:passive_organization_id]).to eq organization.id
            expect_confirmed_and_set_ip(user)
            expect(user.memberships.count).to eq 1
          end
        end
      end
    end

    context "user signed in and confirmed with partner" do
      include_context :logged_in_as_user
      it "redirects" do
        expect(user.confirmed?).to be_truthy
        Sidekiq::Worker.clear_all
        get :confirm, params: {id: user.id, code: user.confirmation_token, partner: "bikehub"}
        expect(User.from_auth(cookies.signed[:auth])).to eq(user)
        expect(response).to redirect_to "https://parkit.bikehub.com/account?reauthenticate_bike_index=true"
        expect(session[:partner]).to be_nil
      end
    end

    it "shows an appropriate message when the user is nil" do
      get :confirm, params: {id: 1234, code: "Wtfmate"}
      expect(response).to render_template :confirm_error_404
    end
  end

  context "revised" do
    let(:user_attrs) do
      {
        name: "foo",
        email: "foo1@bar.com",
        password: "coolpasswprd$$$$$",
        terms_of_service: "0",
        notification_newsletters: "0"
      }
    end

    context "create attrs" do
      it "renders" do
        expect {
          post :create, params: {user: user_attrs}
        }.to change(User, :count).by(1)
      end
    end
  end

  describe "password_reset" do
    before { expect(user.present?).to be_truthy }

    it "enqueues a password reset email job" do
      expect {
        post :password_reset, params: {email: user.email}
      }.to change(EmailResetPasswordWorker.jobs, :size).by(1)
    end

    context "secondary email" do
      let!(:user_email) { FactoryBot.create(:user_email, user: user) }
      it "enqueues a password reset email job" do
        expect {
          post :password_reset, params: {email: user_email.email}
        }.to change(EmailResetPasswordWorker.jobs, :size).by(1)
        expect(EmailResetPasswordWorker).to have_enqueued_sidekiq_job(user.id)
      end
    end

    context "unconfirmed user" do
      let(:user) { FactoryBot.create(:user) }
      it "enqueues a password reset email job" do
        expect {
          post :password_reset, params: {email: user.email}
        }.to change(EmailResetPasswordWorker.jobs, :size).by(1)
      end
    end

    describe "token present (update password stage)" do
      before { user.update_auth_token("password_reset_token") }
      it "logs in and redirects" do
        post :password_reset, params: {token: user.password_reset_token}
        expect(User.from_auth(cookies.signed[:auth])).to eq(user)
        expect(response).to render_template :update_password
      end

      context "unconfirmed user" do
        let(:user) { FactoryBot.create(:user) }
        it "logs in and redirects" do
          expect(user.confirmed?).to be_falsey
          expect(user.password_reset_token).to be_present
          post :password_reset, params: {token: user.password_reset_token}
          expect(response).to render_template :update_password
          expect(User.from_auth(cookies.signed[:auth])).to eq(user)
          # If they are using the correct token, they got the email we sent,
          # so we can assume they have a confirmed email
          user.reload
          expect(user.confirmed?).to be_truthy
        end
      end

      context "get request" do
        it "renders get request" do
          user.update_auth_token("password_reset_token")
          get :password_reset, params: {token: user.password_reset_token}
          expect(response.code).to eq("200")
        end
      end

      context "token expired" do
        it "redirects to request password reset" do
          user.update_auth_token("password_reset_token", (Time.current - 121.minutes).to_i)
          expect(user.auth_token_expired?("password_reset_token")).to be_truthy
          post :password_reset, params: {token: user.password_reset_token}
          expect(flash[:error]).to be_present
          expect(cookies.signed[:auth]).to_not be_present
          expect(response).to render_template :request_password_reset
        end
      end

      context "token invalid" do
        it "does not log in if the token is present and invalid" do
          post :password_reset, params: {token: "Not Actually a token"}
          expect(response).to render_template :request_password_reset
        end
      end
    end
  end

  describe "show" do
    before { expect(user.confirmed).to be_truthy }
    it "404s if the user doesn't exist" do
      expect {
        get :show, params: {id: "fake_user extra stuff"}
      }.to raise_error(ActionController::RoutingError)
    end

    it "redirects to user home url if the user exists but doesn't want to show their page" do
      user.show_bikes = false
      user.save
      get :show, params: {id: user.username}
      expect(response).to redirect_to my_account_url
    end

    it "shows the page if the user exists and wants to show their page" do
      user.show_bikes = true
      user.save
      get :show, params: {id: user.username, page: 1, per_page: 1}
      expect(response).to render_template :show
      expect(assigns(:per_page)).to eq "1"
      expect(assigns(:page)).to eq "1"
    end
  end

  describe "accept_vendor_terms" do
    it "renders" do
      set_current_user(user)
      get :accept_vendor_terms
      expect(response.status).to eq(200)
      expect(response).to render_template(:accept_vendor_terms)
      expect(response).to render_template("layouts/application")
    end
  end

  describe "accept_terms" do
    it "renders" do
      set_current_user(user)
      get :accept_terms
      expect(response).to render_template(:accept_terms)
    end
  end

  describe "edit" do
    include_context :logged_in_as_user
    context "no page given" do
      it "renders root" do
        get :edit
        expect(response).to be_ok
        expect(assigns(:edit_template)).to eq("root")
        expect(response).to render_template("edit")
        expect(response).to render_template("layouts/application")
      end
    end
    context "application layout" do
      %w[root password sharing].each do |template|
        context template do
          it "renders the template" do
            get :edit, params: {page: template}
            expect(response).to be_ok
            expect(assigns(:edit_template)).to eq(template)
            expect(response).to render_template(partial: "_edit_#{template}")
            expect(response).to render_template("layouts/application")
          end
        end
      end
    end
  end

  describe "update" do
    let!(:user) { FactoryBot.create(:user_confirmed, terms_of_service: false, password: "old_password", password_confirmation: "old_password", username: "something") }
    context "nil username" do
      it "doesn't update username" do
        user.reload
        expect(user.username).to eq "something"
        set_current_user(user)
        post :update, params: {id: user.username, user: {username: " ", name: "tim"}, page: "sharing"}
        expect(assigns(:edit_template)).to eq("sharing")
        user.reload
        expect(user.username).to eq("something")
      end
    end

    it "doesn't update user if current password not present" do
      set_current_user(user)
      post :update, params: {
        id: user.username,
        user: {
          password: "new_password",
          password_confirmation: "new_password"
        }
      }
      expect(user.reload.authenticate("new_password")).to be_falsey
    end

    it "doesn't update user if password doesn't match" do
      set_current_user(user)
      post :update, params: {
        id: user.username,
        user: {
          current_password: "old_password",
          password: "new_password",
          name: "Mr. Slick",
          password_confirmation: "new_passwordd"
        }
      }
      expect(user.reload.authenticate("new_password")).to be_falsey
      expect(user.name).not_to eq("Mr. Slick")
    end

    it "Updates user if there is a reset_pass token" do
      user.update_auth_token("password_reset_token", (Time.current - 30.minutes).to_i)
      user.reload
      auth = user.auth_token
      email = user.email
      set_current_user(user)
      post :update, params: {
        id: user.username,
        user: {
          email: "cool_new_email@something.com",
          password_reset_token: user.password_reset_token,
          password: "new_password",
          password_confirmation: "new_password"
        }
      }
      expect(user.reload.authenticate("new_password")).to be_truthy
      expect(user.email).to eq(email)
      expect(user.password_reset_token).not_to eq("stuff")
      expect(user.auth_token).not_to eq(auth)
      expect(cookies.signed[:auth][1]).to eq(user.auth_token)
      expect(response).to redirect_to(edit_my_account_url)
    end

    it "Doesn't updates user if reset_pass token doesn't match" do
      user.update_auth_token("password_reset_token")
      user.reload
      reset = user.password_reset_token
      user.auth_token
      user.email
      set_current_user(user)
      post :update, params: {
        id: user.username,
        user: {
          password_reset_token: "something_else",
          password: "new_password",
          password_confirmation: "new_password"
        }
      }
      expect(response).to_not redirect_to(edit_my_account_url)
      expect(flash[:error]).to be_present
      expect(user.reload.authenticate("new_password")).to be_falsey
      expect(user.password_reset_token).to eq(reset)
    end

    it "Doesn't update user if reset_pass token is more than expiration" do
      user.update_auth_token("password_reset_token", (Time.current - 1.day).to_i)
      auth = user.auth_token
      set_current_user(user)
      expect(cookies[:auth]).to be_present

      post :update, params: {
        id: user.username,
        user: {
          password_reset_token: user.password_reset_token,
          password: "new_password",
          password_confirmation: "new_password"
        }
      }

      expect(response).to_not redirect_to(edit_my_account_url)
      expect(flash[:error]).to be_present
      expect(user.authenticate("new_password")).not_to be_truthy
      expect(user.auth_token).to eq(auth)
      expect(user.password_reset_token).not_to eq("stuff")
      expect(response.cookies[:auth]).to eq(nil)
    end

    it "resets users auth if password changed, updates current session" do
      user = FactoryBot.create(:user_confirmed, terms_of_service: false, password: "old_password", password_confirmation: "old_password", password_reset_token: "stuff")
      auth = user.auth_token
      email = user.email
      set_current_user(user)
      post :update, params: {
        id: user.username,
        user: {
          email: "cool_new_email@something.com",
          current_password: "old_password",
          password: "new_password",
          name: "Mr. Slick",
          password_confirmation: "new_password"
        }
      }
      expect(response).to redirect_to(edit_my_account_url)
      expect(flash[:error]).to_not be_present
      expect(user.reload.authenticate("new_password")).to be_truthy
      expect(user.auth_token).not_to eq(auth)
      expect(user.email).to eq(email)
      expect(user.password_reset_token).not_to eq("stuff")
      expect(user.name).to eq("Mr. Slick")
      expect(cookies.signed[:auth][1]).to eq(user.auth_token)
    end

    context "setting address" do
      let(:country) { Country.united_states }
      let(:state) { FactoryBot.create(:state, name: "New York", abbreviation: "NY") }
      it "sets address, geocodes" do
        set_current_user(user)
        expect(user.notification_newsletters).to be_falsey
        post :update, params: {
          id: user.username,
          user: {
            name: "Mr. Slick",
            country_id: country.id,
            state_id: state.id,
            city: "New York",
            street: "278 Broadway",
            zipcode: "10007",
            notification_newsletters: "1",
            phone: "3223232"
          }
        }
        expect(response).to redirect_to(edit_my_account_url)
        expect(flash[:error]).to_not be_present
        user.reload
        expect(user.name).to eq("Mr. Slick")
        expect(user.country).to eq country
        expect(user.state).to eq state
        expect(user.street).to eq "278 Broadway"
        expect(user.zipcode).to eq "10007"
        expect(user.notification_newsletters).to be_truthy
        expect(user.latitude).to eq default_location[:latitude]
        expect(user.longitude).to eq default_location[:longitude]
        expect(user.phone).to eq "3223232"
      end
    end

    it "updates the terms of service" do
      set_current_user(user)
      post :update, params: {id: user.username, user: {terms_of_service: "1"}}
      expect(response).to redirect_to(my_account_url)
      expect(user.reload.terms_of_service).to be_truthy
    end

    describe "preferred_language" do
      it "updates if valid" do
        expect(user.preferred_language).to eq(nil)
        set_current_user(user)
        patch :update, params: {id: user.username, locale: "nl", user: {preferred_language: "en"}}
        expect(flash[:success]).to match(/succesvol/i)
        expect(response).to redirect_to(edit_my_account_url)
        expect(user.reload.preferred_language).to eq("en")
      end

      it "changes from previous if valid" do
        user.update_attribute :preferred_language, "en"
        set_current_user(user)
        patch :update, params: {id: user.username, locale: "en", user: {preferred_language: "nl"}}
        expect(flash[:success]).to match(/successfully updated/i)
        expect(response).to redirect_to(edit_my_account_url)
        expect(user.reload.preferred_language).to eq("nl")
      end

      it "does not update the preferred_language if invalid" do
        expect(user.preferred_language).to eq(nil)
        set_current_user(user)
        patch :update, params: {id: user.username, user: {preferred_language: "klingon"}}
        expect(flash[:success]).to be_blank
        expect(response).to render_template(:edit)
        expect(user.reload.preferred_language).to eq(nil)
      end
    end

    it "updates notification" do
      set_current_user(user)
      expect(user.notification_unstolen).to be_truthy # Because it's set to true by default
      post :update, params: {id: user.username, user: {notification_newsletters: "1", notification_unstolen: "0"}}
      expect(response).to redirect_to edit_my_account_url
      user.reload
      expect(user.notification_newsletters).to be_truthy
      expect(user.notification_unstolen).to be_falsey
    end

    context "organization with hotsheet" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }
      let!(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: organization, is_on: true) }
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      let(:membership) { user.memberships.first }
      it "updates hotsheet" do
        set_current_user(user)
        expect(membership.notification_never?).to be_truthy
        request.env["HTTP_REFERER"] = organization_hot_sheet_path(organization_id: organization.to_param)
        # Doesn't include the parameter because when false, it doesn't include
        patch :update, params: {
          id: user.username,
          hot_sheet_organization_ids: organization.id.to_s,
          hot_sheet_notifications: {organization.id.to_s => "1"}
        }
        expect(flash[:success]).to be_present
        expect(response).to redirect_to organization_hot_sheet_path(organization_id: organization.to_param)
        membership.reload
        expect(membership.notification_daily?).to be_truthy
      end
      context "with other parameters too" do
        let(:hot_sheet_configuration2) { FactoryBot.create(:hot_sheet_configuration, is_on: true) }
        let(:organization2) { hot_sheet_configuration2.organization }
        let!(:membership2) { FactoryBot.create(:membership_claimed, organization: organization2, user: user, hot_sheet_notification: "notification_daily") }
        it "updates all the parameters" do
          set_current_user(user)
          expect(membership.notification_never?).to be_truthy
          expect(membership2.notification_daily?).to be_truthy
          put :update, params: {
            id: user.username,
            hot_sheet_organization_ids: "#{organization.id},#{organization2.id}",
            hot_sheet_notifications: {organization.id.to_s => "1"},
            user: {
              notification_newsletters: "true",
              notification_unstolen: "false"
            }
          }
          expect(flash[:success]).to be_present
          expect(response).to redirect_to edit_my_account_url
          membership.reload
          membership2.reload
          expect(membership.notification_daily?).to be_truthy
          expect(membership2.notification_daily?).to be_falsey

          user.reload
          expect(user.notification_newsletters).to be_truthy
          expect(user.notification_unstolen).to be_falsey
        end
      end
    end

    it "updates the vendor terms of service and emailable" do
      user = FactoryBot.create(:user_confirmed, terms_of_service: false, notification_newsletters: false)
      expect(user.notification_newsletters).to be_falsey
      organization = FactoryBot.create(:organization)
      FactoryBot.create(:membership_claimed, organization: organization, user: user)
      user.reload
      expect(user.default_organization).to eq organization
      set_current_user(user)
      post :update, params: {id: user.username, user: {vendor_terms_of_service: "1", notification_newsletters: true}}
      expect(response.code).to eq("302")
      expect(response).to redirect_to organization_root_url(organization_id: organization.to_param)
      expect(user.reload.accepted_vendor_terms_of_service?).to be_truthy
      expect(user.when_vendor_terms_of_service).to be_within(1.second).of Time.current
      expect(user.notification_newsletters).to be_truthy
    end

    it "enqueues job (it enqueues job whenever update is successful)" do
      set_current_user(user)
      expect {
        post :update, params: {id: user.username, user: {name: "Cool stuff"}}
      }.to change(AfterUserChangeWorker.jobs, :size).by(1)
      expect(user.reload.name).to eq("Cool stuff")
    end

    describe "submit without updating terms" do
      it "redirects to accept the terms" do
        set_current_user(user)
        post :update, params: {id: user.username, user: {terms_of_service: "0"}}
        expect(response).to redirect_to accept_terms_path
        expect(user.reload.terms_of_service).to be_falsey
      end
      context "vendor_terms" do
        let(:user) { FactoryBot.create(:user_confirmed) }
        it "redirects to accept the terms" do
          expect(user.terms_of_service).to be_truthy
          expect(user.accepted_vendor_terms_of_service?).to be_falsey
          set_current_user(user)
          post :update, params: {id: user.username, user: {vendor_terms_of_service: "0"}}
          expect(response).to redirect_to accept_vendor_terms_path
          expect(user.reload.vendor_terms_of_service).to be_falsey
        end
      end
    end
  end

  describe "unsubscribe" do
    context "subscribed unconfirmed user" do
      let(:user) { FactoryBot.create(:user, notification_newsletters: true) }
      it "updates notification_newsletters" do
        expect(user.notification_newsletters).to be_truthy
        expect(user.confirmed?).to be_falsey
        get :unsubscribe, params: {id: user.username}
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
        user.reload
        expect(user.notification_newsletters).to be_falsey
        expect(user.confirmed).to be_falsey
      end
    end
    context "user not present" do
      it "does not error, shows same flash success (to prevent email enumeration)" do
        get :unsubscribe, params: {id: "cvxvxxxxx"}
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
      end
    end
    context "user already unsubscribed" do
      let(:user) { FactoryBot.create(:user_confirmed, notification_newsletters: false) }
      it "does nothing" do
        expect(user.notification_newsletters).to be_falsey
        get :unsubscribe, params: {id: user.username}
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
        user.reload
        expect(user.notification_newsletters).to be_falsey
      end
    end
  end
end
