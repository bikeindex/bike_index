require "rails_helper"

RSpec.describe UsersController, type: :request do
  base_url = "/users"

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
        expect(current_user.default_organization).to eq organization
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
      }.to_not change(EmailConfirmationJob, :jobs) # Because it's done inline
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
        }.to_not change(EmailConfirmationJob, :jobs) # Because it's done inline
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
        }.to_not change(EmailConfirmationJob, :jobs) # Because it's done inline
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
          }.to_not change(EmailConfirmationJob, :jobs) # Because it's done inline
          expect(response).to redirect_to please_confirm_email_users_path
          expect(flash[:error]).to be_present
          expect(ActionMailer::Base.deliveries.count).to eq 0
          expect(Notification.count).to eq 0
        end
      end
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
        }.to_not change(EmailResetPasswordJob.jobs, :size)
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
        }.to change(EmailResetPasswordJob.jobs, :size).by(1)
        expect(EmailResetPasswordJob).to have_enqueued_sidekiq_job(user.id)
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
        }.to change(EmailResetPasswordJob.jobs, :size).by(1)
        user.reload
        expect(user.token_for_password_reset).to be_present
        expect(user.confirmed?).to be_falsey
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
        }.to_not change(EmailResetPasswordJob.jobs, :size)
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
          }.to change(EmailResetPasswordJob.jobs, :size).by(1)
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
        user.update_auth_token("token_for_password_reset", Time.current - 121.minutes)
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
        user.update_auth_token("token_for_password_reset", Time.current - 3.hours)
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
    let(:user) { FactoryBot.create(:user_confirmed) }
    it "404s if the user doesn't exist" do
      get "#{base_url}/fake_user-extra-stuff"
      expect(response.status).to eq 404
    end

    it "redirects to user home url if the user exists but doesn't want to show their page" do
      user.show_bikes = false
      user.save
      get "#{base_url}/#{user.username}"
      expect(response).to redirect_to my_account_url
    end

    it "shows the page if the user exists and wants to show their page" do
      user.update(show_bikes: true)
      get "#{base_url}/#{user.username}?page=1&per_page=1"
      expect(response).to render_template :show
      expect(assigns(:per_page)).to eq "1"
      # Test some header tag properties
      html_response = response.body
      expect(html_response).to match(/<title>#{user.name}</)
    end
  end

  describe "unsubscribe" do
    let!(:user) { FactoryBot.create(:user_confirmed, notification_newsletters: true) }
    it "renders" do
      expect(user.notification_newsletters).to be_truthy
      expect(user.confirmed?).to be_truthy
      get "#{base_url}/#{user.username}/unsubscribe"
      expect(assigns(:user)&.id).to eq user.id
      expect(response.code).to eq("200")
      expect(response).to render_template("users/unsubscribe")
      expect(flash).to be_blank
      expect(user.reload.notification_newsletters).to be_truthy
    end
    context "current_user" do
      include_context :request_spec_logged_in_as_user
      let(:current_user) { FactoryBot.create(:user_confirmed, notification_newsletters: true) }
      it "renders current user instead" do
        expect(user.notification_newsletters).to be_truthy
        expect(user.confirmed?).to be_truthy
        expect(current_user.notification_newsletters).to be_truthy
        get "#{base_url}/#{user.username}/unsubscribe"
        expect(assigns(:user)&.id).to eq current_user.id
        expect(response.code).to eq("200")
        expect(response).to render_template("users/unsubscribe")
        expect(flash).to be_blank
        expect(user.reload.notification_newsletters).to be_truthy
        expect(current_user.reload.notification_newsletters).to be_truthy
      end
    end
    context "subscribed unconfirmed user" do
      let(:user) { FactoryBot.create(:user, notification_newsletters: true) }
      it "renders" do
        expect(user.notification_newsletters).to be_truthy
        expect(user.confirmed?).to be_falsey
        get "#{base_url}/#{user.username}/unsubscribe"
        expect(assigns(:user)&.id).to eq user.id
        expect(response.code).to eq("200")
        expect(response).to render_template("users/unsubscribe")
        expect(flash).to be_blank
        expect(user.reload.notification_newsletters).to be_truthy
      end
    end
    context "user not present" do
      it "does not error, shows same flash success (to prevent email enumeration)" do
        get "#{base_url}/cvxvxxxxx/unsubscribe"
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
      end
    end
    context "user already unsubscribed" do
      let(:user) { FactoryBot.create(:user_confirmed, notification_newsletters: false) }
      it "renders" do
        expect(user.notification_newsletters).to be_falsey
        get "#{base_url}/#{user.username}/unsubscribe"
        expect(assigns(:user)&.id).to eq user.id
        expect(response.code).to eq("200")
        expect(response).to render_template("users/unsubscribe")
        expect(flash).to be_blank
        expect(user.reload.notification_newsletters).to be_falsey
      end
    end
  end

  describe "unsubscribe" do
    let!(:user) { FactoryBot.create(:user_confirmed, notification_newsletters: true) }
    it "unsubscribes" do
      expect(user.notification_newsletters).to be_truthy
      expect(user.confirmed?).to be_truthy
      post "#{base_url}/#{user.username}/unsubscribe_update"
      expect(response.code).to eq("302")
      expect(flash[:success]).to be_present
      user.reload
      expect(user.notification_newsletters).to be_falsey
    end
    context "current_user" do
      include_context :request_spec_logged_in_as_user
      let(:current_user) { FactoryBot.create(:user_confirmed, notification_newsletters: true) }
      it "unsubscribes current user instead" do
        expect(user.notification_newsletters).to be_truthy
        expect(user.confirmed?).to be_truthy
        expect(current_user.notification_newsletters).to be_truthy
        post "#{base_url}/#{user.username}/unsubscribe_update"
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
        expect(user.reload.notification_newsletters).to be_truthy
        expect(current_user.reload.notification_newsletters).to be_falsey
      end
    end
    context "subscribed unconfirmed user" do
      let(:user) { FactoryBot.create(:user, notification_newsletters: true) }
      it "updates notification_newsletters" do
        expect(user.notification_newsletters).to be_truthy
        expect(user.confirmed?).to be_falsey
        post "#{base_url}/#{user.username}/unsubscribe_update"
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
        user.reload
        expect(user.notification_newsletters).to be_falsey
        expect(user.confirmed).to be_falsey
      end
    end
    context "user not present" do
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
        post "#{base_url}/#{user.username}/unsubscribe_update"
        expect(response.code).to eq("302")
        expect(flash[:success]).to be_present
        user.reload
        expect(user.notification_newsletters).to be_falsey
      end
    end
  end
end
