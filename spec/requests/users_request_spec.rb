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
      expect {
        post "#{base_url}/resend_confirmation_email", params: {email: "stuff@stuff.com"}
      }.to_not change(EmailConfirmationWorker, :jobs) # Because it's done inline
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
        }.to_not change(EmailConfirmationWorker, :jobs) # Because it's done inline
        expect(response).to redirect_to please_confirm_email_users_path
        expect(flash[:success]).to be_present
        expect(ActionMailer::Base.deliveries.count).to eq 1

        # Doing it multiple times doesn't lead to sending multiple notifications
        post "#{base_url}/resend_confirmation_email", params: {email: current_user.email}
        post "#{base_url}/resend_confirmation_email", params: {email: "other stuff"}
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
        expect {
          post "#{base_url}/resend_confirmation_email", params: {email: "test@stuff.com"}
        }.to_not change(EmailConfirmationWorker, :jobs) # Because it's done inline
        expect(response).to redirect_to please_confirm_email_users_path
        expect(flash[:success]).to be_present
        expect(ActionMailer::Base.deliveries.count).to eq 1

        # Doing it multiple times doesn't lead to sending multiple notifications
        post "#{base_url}/resend_confirmation_email", params: {email: "test@stuff.com"}
        expect(ActionMailer::Base.deliveries.count).to eq 1

        expect(user_subject.notifications.count).to eq 1
        expect(user_subject.notifications.last.email_success?).to be_truthy
        expect(user_subject.notifications.last.confirmation_email?).to be_truthy
      end
      context "user confirmed" do
        let!(:user_subject) { FactoryBot.create(:user_confirmed, email: "test@stuff.com") }
        it "does not send a notification" do
          expect(user_subject.confirmed?).to be_truthy
          ActionMailer::Base.deliveries = []
          expect {
            post "#{base_url}/resend_confirmation_email", params: {email: "test@stuff.com"}
          }.to_not change(EmailConfirmationWorker, :jobs) # Because it's done inline
          expect(response).to redirect_to please_confirm_email_users_path
          expect(flash[:error]).to be_present
          expect(ActionMailer::Base.deliveries.count).to eq 0
          expect(Notification.count).to eq 0
        end
      end
    end
  end

  describe "confirm" do
    let(:email) { "cool-new-email@example.com" }
    let!(:user) { FactoryBot.create(:user, email: email) }
    let!(:appointment) { FactoryBot.create(:appointment, email: email) }
    let!(:ownership) { FactoryBot.create(:ownership, owner_email: email) }
    it "confirms the user and associates things" do
      expect(user.confirmed?).to be_falsey
      expect(appointment.user_id).to be_blank
      expect(ownership.user_id).to be_blank
      expect(ownership.bike.user&.id).to be_blank
      ActionMailer::Base.deliveries = []
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.inline! do
        get "#{base_url}/confirm?id=#{user.id}&code=#{user.confirmation_token}"
        expect(response).to redirect_to(/my_account/)
        expect(flash[:success]).to be_present
      end
      # We shouldn't have sent any emails
      expect(ActionMailer::Base.deliveries.count).to eq 0
      user.reload
      expect(user.confirmed?).to be_truthy
      expect(user.appointments.pluck(:id)).to eq([appointment.id])
      expect(user.ownerships.pluck(:id)).to eq([ownership.id])
      expect(user.bikes.pluck(:id)).to eq([ownership.bike_id]) # We need to ensure the user has the bike
      ownership.reload
      expect(ownership.claimed?).to be_falsey # The ownership isn't claimed, but they can see the bike
      expect(ownership.bike.user&.id).to eq user.id
      expect(ownership.user_id).to eq(user.id)
    end
  end
end
