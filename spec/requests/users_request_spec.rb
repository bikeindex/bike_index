require "rails_helper"

RSpec.describe UsersController, type: :request do
  base_url = "/users"

  describe "please_confirm_email" do
    it "renders" do
      get "#{base_url}/please_confirm_email"
      expect(response).to render_template(:please_confirm_email)
      expect(flash).to be_blank
    end
    context "require_signed_in" do
      it "redirects" do
        # So that we can ensure the "resend confirmation" link shows up if we want
        get "#{base_url}/please_confirm_email?require_sign_in=true"
        expect(response).to redirect_to new_session_path
      end
      context "signed in" do
        let(:current_user) { FactoryBot.create(:user) }
        xit "renders" do
          # Unfortunately, I can't figure out how to test this on the unconfirmed_user signed in side...
          allow(User).to receive(:from_auth) { current_user }
          get "#{base_url}/please_confirm_email?require_sign_in=true"
          expect(response).to render_template(:please_confirm_email)
          expect(flash).to be_blank
        end
      end
    end
  end
  describe "resend_confirmation_email" do
    it "doesn't send anything" do
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
  end
end
