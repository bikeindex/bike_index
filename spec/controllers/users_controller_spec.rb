require "rails_helper"

# Need controller specs to test setting session
#
# PUT ALL TESTS IN Request spec !
#
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
            session[:company] = "Some BikeHub"
            get :new, params: {return_to: "/bikes/12?contact_owner=true"}
            expect(session[:return_to]).to eq "/bikes/12?contact_owner=true"
            expect(session[:partner]).to eq "bikehub"
            expect(session[:company]).to eq "Some BikeHub"
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
        terms_of_service: true
      }
    end
    describe "success" do
      it "creates a non-confirmed passwordless record, doesn't block on unknown language" do
        expect {
          post :create, params: {locale: "klingon", user: user_attributes}
        }.to change(User, :count).by(1)
        expect(flash).to_not be_present
        expect(response).to redirect_to(please_confirm_email_users_path)
        user = User.order(:created_at).last
        expect(User.from_auth(cookies.signed[:auth])).to eq user
        expect(user.partner_sign_up).to be_nil
        expect(user.unconfirmed?).to be_truthy
        expect(user.passwordless_user?).to be_truthy
        expect(user.preferred_language).to be_blank # Because language wasn't passed
      end
      it "ignores a submitted password" do
        post :create, params: {user: user_attributes.merge(password: "testthisthing7$")}
        user = User.order(:created_at).last
        expect(user.passwordless_user?).to be_truthy
        expect(user.authenticate("testthisthing7$")).to be_falsey
      end
      context "with locale passed" do
        it "creates a user with a preferred_language" do
          request.env["HTTP_CF_CONNECTING_IP"] = "99.99.99.9"
          Sidekiq::Job.clear_all
          expect {
            post :create, params: {locale: "nl", user: user_attributes}
          }.to change(Email::ConfirmationJob.jobs, :count).by 1

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
            Email::ConfirmationJob.drain
          }.to change(ActionMailer::Base.deliveries, :count).by 1

          mail = ActionMailer::Base.deliveries.last
          expect(mail.subject).to eq("Bevestig uw e-mail met Bike Index!")
          expect(mail.to).to eq([user.email])
          expect(mail.from).to eq(["contact@bikeindex.org"])
        end
      end
      context "with organization_role and an example bike" do
        let(:email) { "test@stuff.com" }
        let(:organization_role) { FactoryBot.create(:organization_role, invited_email: " #{email.upcase}", role: "member") }
        let!(:organization) { organization_role.organization }
        let(:bike) { FactoryBot.create(:bike, example: true, owner_email: email) }
        let!(:ownership) { FactoryBot.create(:ownership, bike: bike, owner_email: email) }
        let(:user_attributes) { {email: email, name: "SAMPLE", terms_of_service: "1", notification_newsletters: "0"} }

        it "creates a confirmed user, logs in, and send welcome even with an example bike" do
          expect(session[:passive_organization_id]).to be_blank
          bike.reload
          expect(bike.user).to be_blank
          Sidekiq::Job.clear_all
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
            expect(CallbackJobs::AfterUserCreateJob.jobs.map { |j| j["args"] }.last.flatten).to eq([user.id, "async"])
            CallbackJobs::AfterUserCreateJob.drain
            bike.reload
            expect(bike.user).to eq user
          }.to change(Email::WelcomeJob.jobs, :count)
        end
      end
      context "with organization_role, partner param" do
        let!(:organization_role) { FactoryBot.create(:organization_role, invited_email: "poo@pile.com") }
        it "creates a confirmed user, log in, and send welcome, language header" do
          session[:passive_organization_id] = "0"
          request.env["HTTP_ACCEPT_LANGUAGE"] = "nl,en;q=0.9"
          allow(Email::WelcomeJob).to receive(:perform_async)

          post :create, params: {user: user_attributes, partner: "bikehub"}

          expect(response).to redirect_to("https://parkit.bikehub.com/account?reauthenticate_bike_index=true")
          user = User.find_by_email("poo@pile.com")
          expect(Email::WelcomeJob).to have_received(:perform_async).with(user.id)
          expect(user.partner_sign_up).to eq "bikehub"
          expect(user.email).to eq "poo@pile.com"

          expect(User.from_auth(cookies.signed[:auth])).to eq user
          expect(user.last_login_at).to be_within(2.seconds).of Time.current
          expect(user.preferred_language).to eq "nl"
          expect(session[:passive_organization_id]).to eq organization_role.organization_id
        end
      end
      context "with partner session" do
        it "renders parter sign in page" do
          session[:partner] = "bikehub"
          session[:company] = "Some BikeHub"
          expect {
            post :create, params: {user: user_attributes}
          }.to change(User, :count).by(1)
          expect(flash).to_not be_present
          expect(response).to redirect_to("https://parkit.bikehub.com/account?reauthenticate_bike_index=true")
          expect(session[:partner]).to be_nil
          expect(session[:company]).to be_nil
          user = User.order(:created_at).last
          expect(user.email).to eq(user_attributes[:email])
          expect(user.partner_sign_up).to eq "bikehub"
          expect(user.partner_data).to eq({sign_up: "bikehub"}.as_json)
          expect(User.from_auth(cookies.signed[:auth])).to eq user
        end
      end
      context "with auto passwordless users" do
        let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["passwordless_users"], user_email_domain: "ladot.online", available_invitation_count: 1) }
        let(:email) { "example@ladot.online" }
        it "Does not create a organization_role or automatically confirm the user" do
          expect(session[:passive_organization_id]).to be_blank
          ActionMailer::Base.deliveries = []
          Sidekiq::Job.clear_all
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
      let(:user_attributes) { {name: "Test name", email: "not-an-email", terms_of_service: true} }
      it "does not create a user or send a welcome email" do
        expect {
          expect {
            post :create, params: {user: user_attributes}
          }.to_not change(Email::WelcomeJob.jobs, :count)
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
    context "honeypot filled" do
      it "creates the user but email bans them as spam" do
        expect {
          post :create, params: {user: user_attributes.merge(additional: "http://spam.example.com")}
        }.to change(User, :count).by(1)
        user = User.order(:created_at).last
        expect(user.email_banned?).to be_truthy
        email_ban = user.email_bans.last
        expect(email_ban.reason).to eq "honeypot"
        # The ban blocks the confirmation email, so the account can't be activated
        expect {
          Email::ConfirmationJob.new.perform(user.id)
        }.to_not change(ActionMailer::Base.deliveries, :count)
      end
    end
    context "revised" do
      let(:user_attrs) do
        {
          name: "foo",
          email: "foo1@bar.com",
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
  end

  describe "confirm" do
    describe "user exists" do
      it "tells the user to log in when already confirmed" do
        post :confirm, params: {id: user.id, code: "wtfmate"}
        expect(response).to redirect_to new_session_url
      end

      describe "user not yet confirmed" do
        let!(:user) { FactoryBot.create(:user) }

        it "logins and redirect when confirmation succeeds" do
          post :confirm, params: {id: user.id, code: user.confirmation_token}
          expect(User.from_auth(cookies.signed[:auth])).to eq(user)
          expect(response).to redirect_to my_account_url
          expect(session[:partner]).to be_nil
          expect(flash[:success]).to eq "Logged in!"
          expect(flash[:notice]).to be_blank
        end

        context "passwordless user" do
          let!(:user) { FactoryBot.create(:user, passwordless_user: true) }

          it "offers to set a password" do
            post :confirm, params: {id: user.id, code: user.confirmation_token}
            expect(User.from_auth(cookies.signed[:auth])).to eq(user)
            expect(response).to redirect_to my_account_url
            expect(flash[:success]).to be_blank
            expect(flash[:notice]).to eq({translation_key: :signed_up, url: update_password_form_with_reset_token_users_path})
          end

          context "organization passwordless user" do
            let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["passwordless_users"]) }
            let!(:organization_role) { FactoryBot.create(:organization_role_claimed, organization:, user:) }

            it "doesn't offer to set a password" do
              post :confirm, params: {id: user.id, code: user.confirmation_token}
              expect(flash[:success]).to eq "You're signed in"
              expect(flash[:notice]).to be_blank
            end
          end
        end

        context "with partner" do
          it "logins and redirect when confirmation succeeds" do
            post :confirm, params: {id: user.id, code: user.confirmation_token, partner: "bikehub"}
            expect(User.from_auth(cookies.signed[:auth])).to eq(user)
            expect(response).to redirect_to "https://parkit.bikehub.com/account?reauthenticate_bike_index=true"
            expect(session[:partner]).to be_nil
          end
          context "in session" do
            it "logins and redirect when confirmation succeeds" do
              session[:partner] = "bikehub"
              post :confirm, params: {id: user.id, code: user.confirmation_token}
              expect(User.from_auth(cookies.signed[:auth])).to eq(user)
              expect(response).to redirect_to "https://parkit.bikehub.com/account?reauthenticate_bike_index=true"
              expect(session[:partner]).to be_nil
            end
          end
          context "user signed in" do
            it "redirects" do
              expect(user.confirmed?).to be_falsey
              set_current_user(user)
              post :confirm, params: {id: user.id, code: user.confirmation_token, partner: "bikehub"}
              user.reload
              expect(User.from_auth(cookies.signed[:auth])).to eq(user)
              expect(response).to redirect_to "https://parkit.bikehub.com/account?reauthenticate_bike_index=true"
              expect(session[:partner]).to be_nil
              expect(user.confirmed?).to be_truthy
            end
          end
        end

        it "shows a view when confirmation fails" do
          post :confirm, params: {id: user.id, code: "Wtfmate"}
          expect(response).to render_template :confirm_error_bad_token
        end
      end

      context "with auto_passwordless organization" do
        let(:enabled_feature_slugs) { ["passwordless_users"] }
        let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:, user_email_domain: "ladot.online", available_invitation_count: 1) }
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
          post :confirm, params: {id: user.id, code: user.confirmation_token}
          expect(response).to redirect_to my_account_url
          expect(session[:partner]).to be_nil
          expect_confirmed_and_set_ip(user)
          expect(user.organization_roles.count).to eq 0
          expect(session[:passive_organization_id]).to eq "0"
        end
        context "domain matching" do
          let(:email) { "something@ladot.online" }
          it "logins without granting a role" do
            request.env["HTTP_CF_CONNECTING_IP"] = "169.99.69.2"
            expect(user.confirmed?).to be_falsey
            expect(session[:passive_organization_id]).to be_blank
            post :confirm, params: {id: user.id, code: user.confirmation_token}
            expect(response).to redirect_to my_account_url
            expect_confirmed_and_set_ip(user)
            expect(user.organization_roles.count).to eq 0
          end
          context "with user_role_for_user_email_domain" do
            let(:enabled_feature_slugs) { ["passwordless_users", "user_role_for_user_email_domain"] }
            it "logins and redirects to the organization" do
              request.env["HTTP_CF_CONNECTING_IP"] = "169.99.69.2"
              expect(user.confirmed?).to be_falsey
              expect(session[:passive_organization_id]).to be_blank
              post :confirm, params: {id: user.id, code: user.confirmation_token}
              expect(response).to redirect_to organization_root_path(organization_id: organization.to_param)
              expect(session[:passive_organization_id]).to eq organization.id
              expect_confirmed_and_set_ip(user)
              expect(user.organization_roles.count).to eq 1
            end
          end
        end
      end
    end

    context "user signed in and confirmed with partner" do
      include_context :logged_in_as_user
      it "redirects" do
        expect(user.confirmed?).to be_truthy
        Sidekiq::Job.clear_all
        post :confirm, params: {id: user.id, code: user.confirmation_token, partner: "bikehub"}
        expect(User.from_auth(cookies.signed[:auth])).to eq(user)
        expect(response).to redirect_to "https://parkit.bikehub.com/account?reauthenticate_bike_index=true"
        expect(session[:partner]).to be_nil
      end
    end

    it "shows an appropriate message when the user is nil" do
      post :confirm, params: {id: 1234, code: "Wtfmate"}
      expect(response).to render_template :confirm_error_404
    end
  end
end
