require "spec_helper"

describe StolenNotification do
  describe "create" do
    it "enqueues an email job" do
      expect do
        FactoryBot.create(:stolen_notification)
      end.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
    end
  end

  describe "assign_receiver" do
    let(:owner_email) { "stolen@notifyme.com" }
    let(:creator) { FactoryBot.create(:user, email: "creator@notmine.com") }
    let(:bike) { FactoryBot.create(:bike, owner_email: owner_email, creator: creator) }
    let!(:ownership) { FactoryBot.create(:ownership_claimed, bike: bike, owner_email: owner_email, creator: creator) }
    let(:stolen_notification) { StolenNotification.new(subject: "special title", message: "party", reference_url: "https://example.com", bike_id: bike.id, sender: FactoryBot.create(:user)) }
    it "assigns the receiver" do
      expect do
        stolen_notification.save
      end.to change(EmailStolenNotificationWorker.jobs, :size).by 1
      expect(stolen_notification.receiver_email).to eq owner_email
      expect(stolen_notification.receiver).to eq ownership.user
    end

    context "ownership not claimed" do
      let!(:ownership) { FactoryBot.create(:ownership, bike: bike, owner_email: owner_email, creator: creator) }
      it "assigns the receiver" do
        expect do
          stolen_notification.save
        end.to change(EmailStolenNotificationWorker.jobs, :size).by 1
        expect(stolen_notification.receiver_email).to eq "creator@notmine.com"
        expect(stolen_notification.receiver).to eq creator
      end
      context "registered as stolen" do
        let(:bike) { FactoryBot.create(:stolen_bike, owner_email: owner_email, creator: creator) }
        it "sends to the bike owner" do
          expect do
            stolen_notification.save
          end.to change(EmailStolenNotificationWorker.jobs, :size).by 1
          expect(stolen_notification.receiver_email).to eq owner_email
          expect(stolen_notification.receiver).to eq creator # Because it's the only thing we can assign to :/
        end
      end
    end
  end
end
