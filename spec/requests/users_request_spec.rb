require "rails_helper"

RSpec.describe UsersController, type: :request do
  base_url = "/users"

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
      expect do
        post "#{base_url}/resend_confirmation_email", params: { email: "stuff@stuff.com" }
      end.to_not change(EmailConfirmationWorker, :jobs) # Because it's done inline
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
        expect do
          post "#{base_url}/resend_confirmation_email", params: { email: "blah blah blah" }
        end.to_not change(EmailConfirmationWorker, :jobs) # Because it's done inline
        expect(response).to redirect_to please_confirm_email_users_path
        expect(flash[:success]).to be_present
        expect(ActionMailer::Base.deliveries.count).to eq 1

        # Doing it multiple times doesn't lead to sending multiple notifications
        post "#{base_url}/resend_confirmation_email", params: { email: current_user.email }
        post "#{base_url}/resend_confirmation_email", params: { email: "other stuff" }
        expect(ActionMailer::Base.deliveries.count).to eq 1

        expect(current_user.notifications.count).to eq 1
        expect(current_user.notifications.last.email_success?).to be_truthy
        expect(current_user.notifications.last.confirmation_email?).to be_truthy
      end
    end
    context "user found" do
      let!(:user_subject) { FactoryBot.create(:user, email: "test@stuff.com") }
      it "sends email" do
        expect(user_subject.confirmed?).to be_falsey
        expect(user_subject.notifications.count).to eq 0
        ActionMailer::Base.deliveries = []
        expect do
          post "#{base_url}/resend_confirmation_email", params: { email: "test@stuff.com" }
        end.to_not change(EmailConfirmationWorker, :jobs) # Because it's done inline
        expect(response).to redirect_to please_confirm_email_users_path
        expect(flash[:success]).to be_present
        expect(ActionMailer::Base.deliveries.count).to eq 1

        # Doing it multiple times doesn't lead to sending multiple notifications
        post "#{base_url}/resend_confirmation_email", params: { email: "test@stuff.com" }
        expect(ActionMailer::Base.deliveries.count).to eq 1

        expect(user_subject.notifications.count).to eq 1
        expect(user_subject.notifications.last.email_success?).to be_truthy
        expect(user_subject.notifications.last.confirmation_email?).to be_truthy
      end
      context "user confirmed" do
        let!(:user_subject) { FactoryBot.create(:user_confirmed, email: "test@stuff.com")}
        it "does not send a notification" do
          expect(user_subject.confirmed?).to be_truthy
          ActionMailer::Base.deliveries = []
          expect do
            post "#{base_url}/resend_confirmation_email", params: { email: "test@stuff.com" }
          end.to_not change(EmailConfirmationWorker, :jobs) # Because it's done inline
          expect(response).to redirect_to please_confirm_email_users_path
          expect(flash[:error]).to be_present
          expect(ActionMailer::Base.deliveries.count).to eq 0
          expect(Notification.count).to eq 0
        end
      end
    end
  end

  describe "update password" do
    include_context :request_spec_logged_in_as_user
    context "previous password was too short" do
      # Prior to #1738 password requirement was 8 characters.
      # Ensure users who had valid passwords for the previous requirements can update their password
      it "updates password" do
        current_user.update_attribute :password, "old_pass"
        expect(current_user.reload.authenticate("old_pass")).to be_truthy
        patch "#{base_url}/#{current_user.username}", params: {
          user: {
            current_password: "old_pass",
            password: "172ddfasdf1LDF",
            name: "Mr. Slick",
            password_confirmation: "172ddfasdf1LDF"
          }
        }
        expect(response).to redirect_to edit_my_account_path
        expect(flash[:success]).to be_present
        current_user.reload
        expect(current_user.reload.authenticate("172ddfasdf1LDF")).to be_truthy
      end
    end
  end

  # describe "password_reset" do
  #   before { expect(user.present?).to be_truthy }

  #   it "enqueues a password reset email job" do
  #     expect {
  #       post :password_reset, params: {email: user.email}
  #     }.to change(EmailResetPasswordWorker.jobs, :size).by(1)
  #   end

  #   context "secondary email" do
  #     let!(:user_email) { FactoryBot.create(:user_email, user: user) }
  #     it "enqueues a password reset email job" do
  #       expect {
  #         post :password_reset, params: {email: user_email.email}
  #       }.to change(EmailResetPasswordWorker.jobs, :size).by(1)
  #       expect(EmailResetPasswordWorker).to have_enqueued_sidekiq_job(user.id)
  #     end
  #   end

  #   context "unconfirmed user" do
  #     let(:user) { FactoryBot.create(:user) }
  #     it "enqueues a password reset email job" do
  #       expect {
  #         post :password_reset, params: {email: user.email}
  #       }.to change(EmailResetPasswordWorker.jobs, :size).by(1)
  #     end
  #   end

  #   describe "token present (update password stage)" do
  #     before { user.update_auth_token("password_reset_token") }
  #     it "logs in and redirects" do
  #       post :password_reset, params: {token: user.password_reset_token}
  #       expect(User.from_auth(cookies.signed[:auth])).to eq(user)
  #       expect(response).to render_template :update_password
  #     end

  #     context "unconfirmed user" do
  #       let(:user) { FactoryBot.create(:user) }
  #       it "logs in and redirects" do
  #         expect(user.confirmed?).to be_falsey
  #         expect(user.password_reset_token).to be_present
  #         post :password_reset, params: {token: user.password_reset_token}
  #         expect(response).to render_template :update_password
  #         expect(User.from_auth(cookies.signed[:auth])).to eq(user)
  #         # If they are using the correct token, they got the email we sent,
  #         # so we can assume they have a confirmed email
  #         user.reload
  #         expect(user.confirmed?).to be_truthy
  #       end
  #     end

  #     context "get request" do
  #       it "renders get request" do
  #         user.update_auth_token("password_reset_token")
  #         get :password_reset, params: {token: user.password_reset_token}
  #         expect(response.code).to eq("200")
  #       end
  #     end

  #     context "token expired" do
  #       it "redirects to request password reset" do
  #         user.update_auth_token("password_reset_token", (Time.current - 121.minutes).to_i)
  #         expect(user.auth_token_expired?("password_reset_token")).to be_truthy
  #         post :password_reset, params: {token: user.password_reset_token}
  #         expect(flash[:error]).to be_present
  #         expect(cookies.signed[:auth]).to_not be_present
  #         expect(response).to render_template :request_password_reset_form
  #       end
  #     end

  #     context "token invalid" do
  #       it "does not log in if the token is present and invalid" do
  #         post :password_reset, params: {token: "Not Actually a token"}
  #         expect(response).to render_template :request_password_reset_form
  #       end
  #     end
  #   end
  # end

  # it "Updates user if there is a reset_pass token" do
  #     user.update_auth_token("password_reset_token", (Time.current - 30.minutes).to_i)
  #     user.reload
  #     auth = user.auth_token
  #     email = user.email
  #     set_current_user(user)
  #     post :update, params: {
  #       id: user.username,
  #       user: {
  #         email: "cool_new_email@something.com",
  #         password_reset_token: user.password_reset_token,
  #         password: "new_password",
  #         password_confirmation: "new_password"
  #       }
  #     }
  #     expect(user.reload.authenticate("new_password")).to be_truthy
  #     expect(user.email).to eq(email)
  #     expect(user.password_reset_token).not_to eq("stuff")
  #     expect(user.auth_token).not_to eq(auth)
  #     expect(cookies.signed[:auth][1]).to eq(user.auth_token)
  #     expect(response).to redirect_to(edit_my_account_url)
  #   end

  #   it "Doesn't updates user if reset_pass token doesn't match" do
  #     user.update_auth_token("password_reset_token")
  #     user.reload
  #     reset = user.password_reset_token
  #     user.auth_token
  #     user.email
  #     set_current_user(user)
  #     post :update, params: {
  #       id: user.username,
  #       user: {
  #         password_reset_token: "something_else",
  #         password: "new_password",
  #         password_confirmation: "new_password"
  #       }
  #     }
  #     expect(response).to_not redirect_to(edit_my_account_url)
  #     expect(flash[:error]).to be_present
  #     expect(user.reload.authenticate("new_password")).to be_falsey
  #     expect(user.password_reset_token).to eq(reset)
  #   end

  #   it "Doesn't update user if reset_pass token is more than expiration" do
  #     user.update_auth_token("password_reset_token", (Time.current - 1.day).to_i)
  #     auth = user.auth_token
  #     set_current_user(user)
  #     expect(cookies[:auth]).to be_present

  #     post :update, params: {
  #       id: user.username,
  #       user: {
  #         password_reset_token: user.password_reset_token,
  #         password: "new_password",
  #         password_confirmation: "new_password"
  #       }
  #     }

  #     expect(response).to_not redirect_to(edit_my_account_url)
  #     expect(flash[:error]).to be_present
  #     expect(user.authenticate("new_password")).not_to be_truthy
  #     expect(user.auth_token).to eq(auth)
  #     expect(user.password_reset_token).not_to eq("stuff")
  #     expect(response.cookies[:auth]).to eq(nil)
  #   end

  #   it "resets users auth if password changed, updates current session" do
  #     user = FactoryBot.create(:user_confirmed, terms_of_service: false, password: "old_password", password_confirmation: "old_password", password_reset_token: "stuff")
  #     auth = user.auth_token
  #     email = user.email
  #     set_current_user(user)
  #     post :update, params: {
  #       id: user.username,
  #       user: {
  #         email: "cool_new_email@something.com",
  #         current_password: "old_password",
  #         password: "new_password",
  #         name: "Mr. Slick",
  #         password_confirmation: "new_password"
  #       }
  #     }
  #     expect(response).to redirect_to(edit_my_account_url)
  #     expect(flash[:error]).to_not be_present
  #     expect(user.reload.authenticate("new_password")).to be_truthy
  #     expect(user.auth_token).not_to eq(auth)
  #     expect(user.email).to eq(email)
  #     expect(user.password_reset_token).not_to eq("stuff")
  #     expect(user.name).to eq("Mr. Slick")
  #     expect(cookies.signed[:auth][1]).to eq(user.auth_token)
  #   end

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
      expect(user.password_reset_token).to be_blank
      ActionMailer::Base.deliveries = []
      Sidekiq::Worker.clear_all
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
      expect(user.password_reset_token).to be_present
    end
    context "unknown user" do
      it "redirects back and flash errors if unable to find user" do
        expect {
          post "#{base_url}/send_password_reset_email", params: {email: "some-crazy-email@stuff.com"}
        }.to_not change(EmailResetPasswordWorker.jobs, :size)
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
        }.to change(EmailResetPasswordWorker.jobs, :size).by(1)
        expect(EmailResetPasswordWorker).to have_enqueued_sidekiq_job(user.id)
        user.reload
        expect(user.password_reset_token).to be_present
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
        }.to change(EmailResetPasswordWorker.jobs, :size).by(1)
        user.reload
        expect(user.password_reset_token).to be_present
        expect(user.confirmed?).to be_falsey
      end
    end
    context "existing password reset token" do
      it "does not resend if just sent" do
        user.send_password_reset_email
        og_token = user.password_reset_token
        expect {
          post "#{base_url}/send_password_reset_email", params: {email: user.email}
          expect(response.code).to eq("200")
          expect(response).to render_template(:send_password_reset_email)
          expect(flash).to be_present
        }.to_not change(EmailResetPasswordWorker.jobs, :size)
        user.reload
        expect(user.password_reset_token).to eq og_token
      end
      context "older token" do
        it "updates token and sends" do
          user.update_auth_token("password_reset_token", Time.current - 5.minutes)
          og_token = user.password_reset_token
          expect(og_token).to be_present
          expect {
            post "#{base_url}/send_password_reset_email", params: {email: user.email}
            expect(response.code).to eq("200")
            expect(response).to render_template(:send_password_reset_email)
            expect(flash).to be_blank
          }.to change(EmailResetPasswordWorker.jobs, :size).by(1)
          user.reload
          expect(user.password_reset_token).to_not eq og_token
        end
      end
    end
  end

  describe "update_password_form_with_reset_token" do
    let(:user) { FactoryBot.create(:user) }
    it "renders" do
      user.send_password_reset_email
      og_token = user.password_reset_token
      get "#{base_url}/update_password_form_with_reset_token?token=#{og_token}"
      expect(response.code).to eq("200")
      expect(response).to render_template(:update_password_form_with_reset_token)
      expect(flash).to be_blank
      user.reload
      expect(user.password_reset_token).to eq og_token
    end
    context "nil token" do
      it "redirects" do
        expect(user.password_reset_token).to be_blank # technically, this matches the pasesd token
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
        user.update_auth_token("password_reset_token", Time.current - 121.minutes)
        og_token = user.password_reset_token
        get "#{base_url}/update_password_form_with_reset_token", params: {token: user.email}
        expect(response).to redirect_to request_password_reset_form_users_path
        expect(flash[:error]).to match "expired"
        user.reload
        expect(user.password_reset_token).to eq og_token
      end
    end
  end

  describe "update_password_with_reset_token" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:valid_params) do
      {
        token: user.password_reset_token,
        user: { password: "b79xzcvb9xcvbzaxcvvvcvqwerwe7823412/`!", password_confirmation: "b79xzcvb9xcvbzaxcvvvcvqwerwe7823412/`!" }
      }
    end
    it "updates user and signs in" do
      user.send_password_reset_email
      og_token = user.password_reset_token
      post "#{base_url}/update_password_with_reset_token", params: valid_params
      expect(response).to redirect_to my_account_url(subdomain: false)
      user.reload
      expect(user.password_reset_token).to_not eq og_token
      expect(user.authenticate(valid_params.dig(:user, :password))).to be_truthy
      jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
      expect(jar.signed["auth"]).to eq([user.id, user.auth_token])
    end
    context "unconfirmed user" do
      let(:user) { FactoryBot.create(:user) }
      it "confirms user and signs in" do
        user.send_password_reset_email
        user.reload
        og_token = user.password_reset_token
        expect(user.confirmed?).to be_falsey
        post "#{base_url}/update_password_with_reset_token", params: valid_params
        expect(response).to redirect_to my_account_url
        user.reload
        expect(user.password_reset_token).to_not eq og_token
        expect(user.authenticate(valid_params.dig(:user, :password))).to be_truthy
        jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
        expect(jar.signed["auth"]).to eq([user.id, user.auth_token])
        expect(user.confirmed?).to be_truthy
      end
    end
    # context "user who hasn't accepted terms" do
    #   let(:user) { FactoryBot.create(:user) }
    #   it "redirects to terms" do
    #     user.send_password_reset_email
    #     user.reload
    #     expect(user.confirmed?).to be_falsey
    #     post "#{base_url}/update_password_with_reset_token", params: valid_params
    #     expect(response).to redirect_to my_account_path
    #     pp response.cookies
    #     user.reload
    #     expect(user.password_reset_token).to be_blank
    #     expect(user.authenticate(valid_params.dig(:user, :password))).to be_truthy
    #     expect(response.cookies[:auth]).to eq user.auth_token
    #     expect(user.confirmed?).to be_truthy
    #   end
    # end
    # context "invalid password" do
    #   let(:invalid_params) { valid_params.merge(user: { password: "Too-sh0rt", password_confirmation: "Too-sh0rt" }) }
    #   it "redirects back, doesn't sign in" do
    #     user.send_password_reset_email
    #     og_token = user.password_reset_token
    #     post "#{base_url}/update_password_with_reset_token", params: invalid_params
    #     expect(flash[:error]).to be_present
    #     expect(response).to redirect_to update_password_form_with_reset_token_users_path
    #     user.reload
    #     expect(user.password_reset_token).to eq og_token
    #     expect(user.authenticate(valid_params.dig(:user, :password))).to be_truthy
    #   end
    # end
    # context "incorrect confirmation" do
    #   let(:invalid_params) { valid_params.merge(user: { password: "validvalidvalid", password_confirmation: "invalidvalidvalid" }) }
    #   it "redirects back, doesn't sign in" do
    #     user.send_password_reset_email
    #     og_token = user.password_reset_token
    #     post "#{base_url}/update_password_with_reset_token", params: invalid_params
    #     expect(flash[:error]).to be_present
    #     expect(response).to redirect_to update_password_form_with_reset_token_users_path
    #     user.reload
    #     expect(user.password_reset_token).to eq og_token
    #     expect(user.authenticate(valid_params.dig(:user, :password))).to be_truthy
    #   end
    # end
    # context "nil token" do
    #   it "redirects" do
    #     user.reload
    #     expect(User.find_by_password_reset_token("")&.id).to eq user.id
    #     get "#{base_url}/update_password_with_reset_token", params: valid_params.merge(token: "")
    #     expect(response).to redirect_to request_password_reset_form_users_path
    #     expect(flash[:error]).to be_present
    #     expect(user.authenticate(valid_params.dig(:user, :password))).to be_falsey
    #   end
    # end
    # context "token not found" do
    #   it "redirects" do
    #     get "#{base_url}/update_password_with_reset_token", params: valid_params.merge(token: "uopfqwenafcvxcvasdf")
    #     expect(response).to redirect_to request_password_reset_form_users_path
    #     expect(flash[:error]).to be_present
    #   end
    # end
    # context "auth token expired" do
    #   it "redirects" do
    #     user.update_auth_token("password_reset_token", Time.current - 3.hours)
    #     og_token = user.password_reset_token
    #     get "#{base_url}/update_password_with_reset_token", params: {token: user.email}
    #     expect(response).to redirect_to request_password_reset_form_users_path
    #     expect(flash[:error]).to match "expired"
    #     user.reload
    #     expect(user.password_reset_token).to eq og_token
    #     expect(user.authenticate(valid_params.dig(:user, :password))).to be_falsey
    #   end
    # end
  end
end
