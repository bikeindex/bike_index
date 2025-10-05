require "rails_helper"

RSpec.describe StolenNotification, type: :model do
  describe "create" do
    it "enqueues an email job" do
      expect {
        FactoryBot.create(:stolen_notification)
      }.to change(Email::StolenNotificationJob.jobs, :size).by(1)
    end
  end

  describe "#default_message" do
    it "sets the message value to the ambassador template" do
      user = FactoryBot.create(:user, name: "Index Bikeman")
      notification = FactoryBot.build(:stolen_notification, message: nil, sender: user)

      notification.default_message
      expect(notification.message).to match(/this is #{user.name} with Bike Index/)
      expect(notification.message).to match(/Is this your missing bike?/)
    end
  end

  describe "assign_receiver" do
    let(:owner_email) { "stolen@notifyme.com" }
    let(:creator) { FactoryBot.create(:user, email: "creator@notmine.com") }
    let(:bike) { FactoryBot.create(:bike, owner_email: owner_email, creator: creator) }
    let!(:ownership) { FactoryBot.create(:ownership_claimed, bike: bike, owner_email: owner_email, creator: creator) }
    let(:organization_unstolen) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[unstolen_notifications]) }
    let(:sender) { FactoryBot.create(:organization_user, organization: organization_unstolen) }
    let(:stolen_notification) { StolenNotification.new(subject: "special title", message: "party", reference_url: "https://example.com", bike_id: bike.id, sender: sender) }

    def expect_stolen_notification_to_send(stolen_notification, receiver)
      expect {
        stolen_notification.save
      }.to change(Email::StolenNotificationJob.jobs, :size).by 1
      expect(stolen_notification.receiver).to eq receiver
    end

    it "assigns the receiver" do
      expect_stolen_notification_to_send(stolen_notification, ownership.user)
      expect(stolen_notification.receiver_email).to eq owner_email
      expect(stolen_notification.kind).to eq "unstolen_claimed_permitted"
    end
    context "ownership not claimed" do
      let!(:ownership) { FactoryBot.create(:ownership, bike: bike, owner_email: owner_email, creator: creator, organization: organization) }
      let(:organization) { nil }
      it "assigns the receiver" do
        expect_stolen_notification_to_send(stolen_notification, creator)
        expect(stolen_notification.receiver_email).to eq "creator@notmine.com"
        expect(stolen_notification.kind).to eq "unstolen_unclaimed_permitted"
      end
      context "organization unstolen" do
        let(:organization) { organization_unstolen }
        it "assigns creator" do
          # unstolen organization can just send unstolen, not direct by default
          expect_stolen_notification_to_send(stolen_notification, creator)
          expect(stolen_notification.receiver_email).to eq "creator@notmine.com"
          expect(stolen_notification.kind).to eq "unstolen_unclaimed_permitted"
        end
      end
      context "organization direct_unclaimed_notifications" do
        let(:organization) { FactoryBot.create(:organization, direct_unclaimed_notifications: true) }
        it "assigns the receiver_email" do
          # Still assigns receiver to creator, it's the only thing we can :/
          expect_stolen_notification_to_send(stolen_notification, creator)
          expect(stolen_notification.receiver_email).to eq owner_email
          expect(stolen_notification.kind).to eq "unstolen_unclaimed_permitted_direct"
        end
      end
      context "registered as stolen" do
        let(:bike) { FactoryBot.create(:stolen_bike, owner_email: owner_email, creator: creator) }
        it "sends to the bike owner" do
          # Still assigns receiver to creator, it's the only thing we can :/
          expect_stolen_notification_to_send(stolen_notification, creator)
          expect(stolen_notification.receiver_email).to eq owner_email
          expect(stolen_notification.kind).to eq "stolen_permitted"
        end
      end
    end
  end
end
