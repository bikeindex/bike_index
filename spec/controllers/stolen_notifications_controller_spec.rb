require "spec_helper"

describe StolenNotificationsController do
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:bike) { FactoryBot.create(:bike) }
  let(:user2) { FactoryBot.create(:user) }
  let!(:ownership) { FactoryBot.create(:ownership_claimed, user: user2, bike: bike) }
  let(:stolen_notification_attributes) do
    {
      bike_id: bike.id,
      message: "I saw this bike on the street!",
      reference_url: "https://party.com"
    }
  end

  describe "create" do
    it "fails without user logged in" do
      expect do
        post :create, stolen_notification: stolen_notification_attributes
      end.not_to change(StolenNotification, :count)
    end

    describe "user logged in" do
      it "creates a Stolen Notification record" do
        set_current_user(user)
        bike.reload
        expect(bike.owner.id).to eq user2.id
        expect do
          expect do
            post :create, stolen_notification: stolen_notification_attributes
          end.to change(StolenNotification, :count).by(1)
        end.to change(EmailStolenNotificationWorker.jobs, :count).by(1)
        stolen_notification = StolenNotification.last
        expect(stolen_notification.bike).to eq bike
        expect(stolen_notification.sender_id).to eq user.id
        expect(stolen_notification.receiver_id).to eq user2.id
        expect(stolen_notification.message).to eq stolen_notification_attributes[:message]
        expect(stolen_notification.reference_url).to eq stolen_notification_attributes[:reference_url]
      end
    end
  end
end
