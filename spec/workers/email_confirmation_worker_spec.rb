require "rails_helper"

RSpec.describe EmailConfirmationWorker, type: :job do
  it "sends a welcome email" do
    user = FactoryBot.create(:user)
    ActionMailer::Base.deliveries = []
    EmailConfirmationWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
  context "user with email already exists" do
    let(:email) { "test@test.com" }
    let!(:user1) { FactoryBot.create(:user, email: email) }
    let(:user2) do
      u = FactoryBot.create(:user)
      u.update_column :email, email
      u
    end
    it "deletes user" do
      expect(user1.email).to eq user2.email
      expect(user1.id).to be < user2.id
      ActionMailer::Base.deliveries = []
      expect do
        EmailConfirmationWorker.new.perform(user2.id)
      end.to change(User, :count).by(-1)
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
    end
    context "calling other user" do
      it "does not delete the other user" do
        expect(user1.id).to be < user2.id
        ActionMailer::Base.deliveries = []
        expect do
          EmailConfirmationWorker.new.perform(user1.id)
        end.to change(User, :count).by(0)
        expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      end
    end
    context "recent notification" do
      let(:user) { FactoryBot.create(:user) }
      let!(:notification) { FactoryBot.create(:notification, kind: "confirmation_email", user: user, created_at: created_at, delivery_status: delivery_status) }
      let(:delivery_status) { "email_success" }
      let(:created_at) { Time.current - 30.seconds }
      it "doesn't resend" do
        ActionMailer::Base.deliveries = []
        expect do
          EmailConfirmationWorker.new.perform(user.id)
        end.to change(Notification, :count).by(0)
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
      end
      context "sent 1:10 seconds ago" do
        let(:created_at) { Time.current - 70.seconds }
        it "resends" do
          ActionMailer::Base.deliveries = []
          expect do
            EmailConfirmationWorker.new.perform(user.id)
          end.to change(Notification, :count).by(1)
          expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          notification2 = Notification.last
          expect(notification2.user).to eq user
          expect(notification2.delivery_status).to eq "email_success"
        end
      end
      context "delivery_status nil" do
        let(:delivery_status) { nil }
        it "resends, updates existing notification" do
          ActionMailer::Base.deliveries = []
          expect do
            EmailConfirmationWorker.new.perform(user.id)
          end.to change(Notification, :count).by(0)
          expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          notification.reload
          expect(notification.email_success?).to be_truthy
        end
      end
    end
  end
end
