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
      let(:bike) { FactoryBot.create(:stolen_bike) }
      before { set_current_user(user) }
      it "creates a Stolen Notification record" do
        bike.reload
        expect(bike.owner.id).to eq user2.id
        expect(bike.contact_owner?(user)).to be_truthy
        expect do
          expect do
            post :create, stolen_notification: stolen_notification_attributes
            expect(flash[:success]).to be_present
          end.to change(StolenNotification, :count).by(1)
        end.to change(EmailStolenNotificationWorker.jobs, :count).by(1)
        stolen_notification = StolenNotification.last
        expect(stolen_notification.bike).to eq bike
        expect(stolen_notification.sender_id).to eq user.id
        expect(stolen_notification.receiver_id).to eq user2.id
        expect(stolen_notification.message).to eq stolen_notification_attributes[:message]
        expect(stolen_notification.reference_url).to eq stolen_notification_attributes[:reference_url]
      end
      context "not permitted notification" do
        let(:bike) { FactoryBot.create(:bike) }
        it "fails to create if the user isn't permitted to send a stolen_notification" do
          expect(bike.contact_owner?(user)).to be_falsey
          expect do
            post :create, stolen_notification: stolen_notification_attributes
          end.to_not change(StolenNotification, :count)
          expect(flash[:error]).to be_present
        end
      end
    end
  end
end
