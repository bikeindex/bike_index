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
        expect(user.reload.authenticate("172ddfasdf1LDF")).to be_truthy
      end
    end
  end
end
