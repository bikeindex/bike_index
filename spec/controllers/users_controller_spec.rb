require "spec_helper"

describe UsersController do
  let(:user) { FactoryBot.create(:user_confirmed) }
  describe "new" do
    context "already signed in" do
      include_context :logged_in_as_user
      it "redirects and sets the flash" do
        get :new
        expect(response).to redirect_to(:user_home)
        expect(flash).to be_present
      end
      context "return_to" do
        it "redirects to return_to" do
          get :new, return_to: "/bikes/12?contact_owner=true"
          expect(response).to redirect_to "/bikes/12?contact_owner=true"
        end
      end
      context "unconfirmed" do
        let(:user) { FactoryBot.create(:user) }
        it "redirects to please_confirm_email" do
          get :new, return_to: "/bikes/12?contact_owner=true"
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
      end
      context "with partner param" do
        it "actually sets it" do
          get :new, email: "seth@bikes.com", return_to: "/bikes/12?contact_owner=true", partner: "bikehub"
          expect(assigns(:user).email).to eq "seth@bikes.com"
          expect(session[:return_to]).to eq "/bikes/12?contact_owner=true"
          expect(session[:partner]).to be_nil
        end
        context "with partner session" do
          it "actually sets it" do
            session[:partner] = "bikehub"
            get :new, return_to: "/bikes/12?contact_owner=true"
            expect(session[:return_to]).to eq "/bikes/12?contact_owner=true"
            session[:partner] = "bikehub"
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
        expect(response).to redirect_to user_home_path
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
    context "legacy" do
      let(:user_attributes) { FactoryBot.attributes_for(:user, email: "poo@pile.com") }
      describe "success" do
        it "creates a non-confirmed record" do
          expect do
            post :create, user: FactoryBot.attributes_for(:user)
          end.to change(User, :count).by(1)
          expect(flash).to_not be_present
          expect(response).to redirect_to(please_confirm_email_users_path)
          user = User.order(:created_at).last
          expect(User.from_auth(cookies.signed[:auth])).to eq user
          expect(user.partner_sign_up).to be_nil
          expect(user.partner_sign_up).to be_nil
          expect(user.unconfirmed?).to be_truthy
        end
        context "with organization_invitation and an example bike" do
          let(:email) { "test@stuff.com" }
          let(:organization_invitation) { FactoryBot.create(:organization_invitation, invitee_email: " #{email.upcase}", membership_role: "member") }
          let!(:organization) { organization_invitation.organization }
          let(:bike) { FactoryBot.create(:bike, example: true, owner_email: email) }
          let!(:ownership) { FactoryBot.create(:ownership, bike: bike, owner_email: email) }
          let(:user_attributes) do
            { "email" => email,
              "name" => "SAMPLE",
              "password" => "please12",
              "terms_of_service" => "1",
              "notification_newsletters" => "0" }
          end
          it "creates a confirmed user, logs in, and send welcome even with an example bike" do
            expect(session[:passive_organization_id]).to be_blank
            bike.reload
            expect(bike.user).to be_blank
            expect do
              post :create, user: user_attributes
            end.to change(EmailWelcomeWorker.jobs, :count)
            expect(response).to redirect_to organization_bikes_path(organization_id: organization.to_param)
            user = User.order(:created_at).last
            expect(user.email).to eq email
            expect(User.from_auth(cookies.signed[:auth])).to eq user
            expect(session[:passive_organization_id]).to eq organization.id
            bike.reload
            expect(bike.user).to eq user
          end
        end
        context "with organization_invitation, partner param" do
          let!(:organization_invitation) { FactoryBot.create(:organization_invitation, invitee_email: "poo@pile.com") }
          it "creates a confirmed user, log in, and send welcome" do
            session[:passive_organization_id] = "0"
            expect_any_instance_of(AfterUserCreateWorker).to receive(:send_welcoming_email)
            post :create, user: user_attributes, partner: "bikehub"
            expect(response).to redirect_to("https://new.bikehub.com/account")
            expect(User.order(:created_at).last.partner_sign_up).to eq "bikehub"
            expect(User.from_auth(cookies.signed[:auth])).to eq(User.fuzzy_email_find("poo@pile.com"))
            expect(session[:passive_organization_id]).to eq organization_invitation.organization_id
          end
        end
        context "with partner session" do
          it "renders parter sign in page" do
            session[:partner] = "bikehub"
            expect do
              post :create, user: user_attributes
            end.to change(User, :count).by(1)
            expect(flash).to_not be_present
            expect(response).to redirect_to("https://new.bikehub.com/account")
            expect(session[:partner]).to be_nil
            user = User.order(:created_at).last
            expect(user.email).to eq(user_attributes[:email])
            expect(user.partner_sign_up).to eq "bikehub"
            expect(user.partner_data).to eq({ sign_up: "bikehub" }.as_json)
            expect(User.from_auth(cookies.signed[:auth])).to eq user
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
          expect do
            expect do
              post :create, user: user_attributes
            end.to_not change(EmailWelcomeWorker.jobs, :count)
          end.to_not change(User, :count)
        end
        context "partner param" do
          it "renders new" do
            post :create, partner: "bikehub", user: user_attributes
            expect(response).to render_template("new")
            expect(assigns(:page_errors)).to be_present
          end
        end
      end
    end

    describe "confirm" do
      describe "user exists" do
        it "tells the user to log in when already confirmed" do
          get :confirm, id: user.id, code: "wtfmate"
          expect(response).to redirect_to new_session_url
        end

        describe "user not yet confirmed" do
          let(:user) { FactoryBot.create(:user) }

          before :each do
            expect(User).to receive(:find).and_return(user)
          end

          it "logins and redirect when confirmation succeeds" do
            get :confirm, id: user.id, code: user.confirmation_token
            expect(User.from_auth(cookies.signed[:auth])).to eq(user)
            expect(response).to redirect_to user_home_url
            expect(session[:partner]).to be_nil
          end

          context "with partner" do
            it "logins and redirect when confirmation succeeds" do
              get :confirm, id: user.id, code: user.confirmation_token, partner: "bikehub"
              expect(User.from_auth(cookies.signed[:auth])).to eq(user)
              expect(response).to redirect_to "https://new.bikehub.com/account"
              expect(session[:partner]).to be_nil
            end
            context "in session" do
              it "logins and redirect when confirmation succeeds" do
                session[:partner] = "bikehub"
                get :confirm, id: user.id, code: user.confirmation_token
                expect(User.from_auth(cookies.signed[:auth])).to eq(user)
                expect(response).to redirect_to "https://new.bikehub.com/account"
                expect(session[:partner]).to be_nil
              end
            end
          end

          it "shows a view when confirmation fails" do
            expect(user).to receive(:confirm).and_return(false)
            get :confirm, id: user.id, code: "Wtfmate"
            expect(response).to render_template :confirm_error_bad_token
          end
        end
      end

      it "shows an appropriate message when the user is nil" do
        get :confirm, id: 1234, code: "Wtfmate"
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
          notification_newsletters: "0",
        }
      end

      context "create attrs" do
        it "renders" do
          expect do
            post :create, user: user_attrs
          end.to change(User, :count).by(1)
        end
      end
    end
  end

  describe "password_reset" do
    before { expect(user.present?).to be_truthy }

    it "enqueues a password reset email job" do
      expect do
        post :password_reset, email: user.email
      end.to change(EmailResetPasswordWorker.jobs, :size).by(1)
    end

    context "secondary email" do
      let!(:user_email) { FactoryBot.create(:user_email, user: user) }
      it "enqueues a password reset email job" do
        expect do
          post :password_reset, email: user_email.email
        end.to change(EmailResetPasswordWorker.jobs, :size).by(1)
        expect(EmailResetPasswordWorker).to have_enqueued_sidekiq_job(user.id)
      end
    end

    context "unconfirmed user" do
      let(:user) { FactoryBot.create(:user) }
      it "enqueues a password reset email job" do
        expect do
          post :password_reset, email: user.email
        end.to change(EmailResetPasswordWorker.jobs, :size).by(1)
      end
    end

    describe "token present (update password stage)" do
      before { user.set_password_reset_token }
      it "logs in and redirects" do
        post :password_reset, token: user.password_reset_token
        expect(User.from_auth(cookies.signed[:auth])).to eq(user)
        expect(response).to render_template :update_password
      end

      context "unconfirmed user" do
        let(:user) { FactoryBot.create(:user) }
        it "logs in and redirects" do
          expect(user.confirmed?).to be_falsey
          expect(user.password_reset_token).to be_present
          post :password_reset, token: user.password_reset_token
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
          user.set_password_reset_token
          get :password_reset, token: user.password_reset_token
          expect(response.code).to eq("200")
        end
      end

      context "token expired" do
        it "redirects to request password reset" do
          user.set_password_reset_token((Time.now - 61.minutes).to_i)
          post :password_reset, token: user.password_reset_token
          expect(flash[:error]).to be_present
          expect(cookies.signed[:auth]).to_not be_present
          expect(response).to render_template :request_password_reset
        end
      end

      context "token invalid" do
        it "does not log in if the token is present and invalid" do
          post :password_reset, token: "Not Actually a token"
          expect(response).to render_template :request_password_reset
        end
      end
    end
  end

  describe "show" do
    before { expect(user.confirmed).to be_truthy }
    it "404s if the user doesn't exist" do
      expect do
        get :show, id: "fake_user extra stuff"
      end.to raise_error(ActionController::RoutingError)
    end

    it "redirects to user home url if the user exists but doesn't want to show their page" do
      user.show_bikes = false
      user.save
      get :show, id: user.username
      expect(response).to redirect_to user_home_url
    end

    it "shows the page if the user exists and wants to show their page" do
      user.show_bikes = true
      user.save
      get :show, id: user.username, page: 1, per_page: 1
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
        expect(response).to be_success
        expect(assigns(:edit_template)).to eq("root")
        expect(response).to render_template("edit")
      end
    end
    context "application_revised layout" do
      %w[root password sharing].each do |template|
        context template do
          it "renders the template" do
            get :edit, page: template
            expect(response).to be_success
            expect(assigns(:edit_template)).to eq(template)
            expect(response).to render_template(partial: "_edit_#{template}")
          end
        end
      end
    end
  end

  describe "update" do
    let!(:user) { FactoryBot.create(:user_confirmed, terms_of_service: false, password: "old_pass", password_confirmation: "old_pass", username: "something") }
    context "nil username" do
      it "doesn't update username" do
        user.reload
        expect(user.username).to eq "something"
        set_current_user(user)
        post :update, id: user.username, user: { username: " ", name: "tim" }, page: "sharing"
        expect(assigns(:edit_template)).to eq("sharing")
        user.reload
        expect(user.username).to eq("something")
      end
    end

    it "doesn't update user if current password not present" do
      set_current_user(user)
      post :update, id: user.username,
                    user: {
                      password: "new_pass",
                      password_confirmation: "new_pass",
                    }
      expect(user.reload.authenticate("new_pass")).to be_falsey
    end

    it "doesn't update user if password doesn't match" do
      set_current_user(user)
      post :update, id: user.username,
                    user: {
                      current_password: "old_pass",
                      password: "new_pass",
                      name: "Mr. Slick",
                      password_confirmation: "new_passd",
                    }
      expect(user.reload.authenticate("new_pass")).to be_falsey
      expect(user.name).not_to eq("Mr. Slick")
    end

    it "Updates user if there is a reset_pass token" do
      user.set_password_reset_token((Time.now - 30.minutes).to_i)
      user.reload
      auth = user.auth_token
      email = user.email
      set_current_user(user)
      post :update, id: user.username,
                    user: {
                      email: "cool_new_email@something.com",
                      password_reset_token: user.password_reset_token,
                      password: "new_pass",
                      password_confirmation: "new_pass",
                    }
      expect(user.reload.authenticate("new_pass")).to be_truthy
      expect(user.email).to eq(email)
      expect(user.password_reset_token).not_to eq("stuff")
      expect(user.auth_token).not_to eq(auth)
      expect(cookies.signed[:auth][1]).to eq(user.auth_token)
      expect(response).to redirect_to(my_account_url)
    end

    it "Doesn't updates user if reset_pass token doesn't match" do
      user.set_password_reset_token
      user.reload
      reset = user.password_reset_token
      user.auth_token
      user.email
      set_current_user(user)
      post :update, id: user.username,
                    user: {
                      password_reset_token: "something_else",
                      password: "new_pass",
                      password_confirmation: "new_pass",
                    }
      expect(response).to_not redirect_to(my_account_url)
      expect(flash[:error]).to be_present
      expect(user.reload.authenticate("new_pass")).to be_falsey
      expect(user.password_reset_token).to eq(reset)
    end

    it "Doesn't update user if reset_pass token is more than an hour old" do
      user.set_password_reset_token((Time.now - 61.minutes).to_i)
      auth = user.auth_token
      user.email
      set_current_user(user)
      post :update, id: user.username,
                    user: {
                      password_reset_token: user.password_reset_token,
                      password: "new_pass",
                      password_confirmation: "new_pass",
                    }
      expect(response).to_not redirect_to(my_account_url)
      expect(flash[:error]).to be_present
      user.reload
      expect(user.authenticate("new_pass")).not_to be_truthy
      expect(user.auth_token).to eq(auth)
      expect(user.password_reset_token).not_to eq("stuff")
      expect(cookies.signed[:auth]).to_not be_present
    end

    it "resets users auth if password changed, updates current session" do
      user = FactoryBot.create(:user_confirmed, terms_of_service: false, password: "old_pass", password_confirmation: "old_pass", password_reset_token: "stuff")
      auth = user.auth_token
      email = user.email
      set_current_user(user)
      post :update, id: user.username,
                    user: {
                      email: "cool_new_email@something.com",
                      current_password: "old_pass",
                      password: "new_pass",
                      name: "Mr. Slick",
                      password_confirmation: "new_pass",
                    }
      expect(response).to redirect_to(my_account_url)
      expect(flash[:error]).to_not be_present
      expect(user.reload.authenticate("new_pass")).to be_truthy
      expect(user.auth_token).not_to eq(auth)
      expect(user.email).to eq(email)
      expect(user.password_reset_token).not_to eq("stuff")
      expect(user.name).to eq("Mr. Slick")
      expect(cookies.signed[:auth][1]).to eq(user.auth_token)
    end

    context "setting address" do
      let(:country) { Country.united_states }
      let(:state) { FactoryBot.create(:state, name: "New York", abbreviation: "NY") }
      include_context :geocoder_default_location
      it "sets address, geocodes" do
        set_current_user(user)
        expect(user.notification_newsletters).to be_falsey
        post :update, id: user.username,
                      user: {
                        name: "Mr. Slick",
                        country_id: country.id,
                        state_id: state.id,
                        city: "New York",
                        street: "278 Broadway",
                        zipcode: "10007",
                        notification_newsletters: "1",
                        phone: "3223232",
                      }
        expect(response).to redirect_to(my_account_url)
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
      post :update, id: user.username, user: { terms_of_service: "1" }
      expect(response).to redirect_to(user_home_url)
      expect(user.reload.terms_of_service).to be_truthy
    end

    it "updates notification" do
      set_current_user(user)
      expect(user.notification_unstolen).to be_truthy # Because it's set to true by default
      post :update, id: user.username, user: { notification_newsletters: "1", notification_unstolen: "0" }
      expect(response).to redirect_to my_account_url
      user.reload
      expect(user.notification_newsletters).to be_truthy
      expect(user.notification_unstolen).to be_falsey
    end

    it "updates the vendor terms of service and emailable" do
      user = FactoryBot.create(:user_confirmed, terms_of_service: false, notification_newsletters: false)
      expect(user.notification_newsletters).to be_falsey
      org = FactoryBot.create(:organization)
      FactoryBot.create(:membership, organization: org, user: user)
      set_current_user(user)
      post :update, id: user.username, user: { vendor_terms_of_service: "1", notification_newsletters: true }
      expect(response.code).to eq("302")
      expect(user.reload.vendor_terms_of_service).to be_truthy
      expect(user.notification_newsletters).to be_truthy
    end

    it "enqueues job (it enqueues job whenever update is successful)" do
      set_current_user(user)
      expect do
        post :update, id: user.username, user: { name: "Cool stuff" }
      end.to change(AfterUserChangeWorker.jobs, :size).by(1)
      expect(user.reload.name).to eq("Cool stuff")
    end
  end
  describe "unsubscribe" do
    context "subscribed unconfirmed user" do
      let(:user) { FactoryBot.create(:user, notification_newsletters: true) }
      it "updates notification_newsletters" do
        expect(user.notification_newsletters).to be_truthy
        expect(user.confirmed?).to be_falsey
        get :unsubscribe, id: user.username
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
        user.reload
        expect(user.notification_newsletters).to be_falsey
        expect(user.confirmed).to be_falsey
      end
    end
    context "user not present" do
      it "does not error, shows same flash success (to prevent email enumeration)" do
        get :unsubscribe, id: "cvxvxxxxx"
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
      end
    end
    context "user already unsubscribed" do
      let(:user) { FactoryBot.create(:user_confirmed, notification_newsletters: false) }
      it "does nothing" do
        expect(user.notification_newsletters).to be_falsey
        get :unsubscribe, id: user.username
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
        user.reload
        expect(user.notification_newsletters).to be_falsey
      end
    end
  end
end
