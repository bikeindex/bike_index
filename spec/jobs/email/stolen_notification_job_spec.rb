require "rails_helper"

RSpec.describe Email::StolenNotificationJob, type: :job do
  let(:subject) { Email::StolenNotificationJob }
  let(:instance) { subject.new }
  let(:creator) { FactoryBot.create(:user_confirmed) }
  let(:owner_email) { "targetbike@example.org" }
  let(:user) { FactoryBot.create(:user) }
  let(:bike) { FactoryBot.create(:stolen_bike, owner_email: owner_email, creator: creator) }
  let!(:ownership) { FactoryBot.create(:ownership_claimed, bike: bike, creator: creator) }
  let!(:stolen_notification) { FactoryBot.create(:stolen_notification, bike: bike.reload, sender: user) }
  let(:organization) do
    o = FactoryBot.create(:organization)
    o.update_attribute :enabled_feature_slugs, %w[unstolen_notifications]
    o
  end
  before { ActionMailer::Base.deliveries = [] }

  def expect_notification_sent(sender_email, override_email = nil)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    mail = ActionMailer::Base.deliveries.last
    expect(mail.subject).to eq("Stolen bike contact")
    expect(mail.to).to eq([override_email || owner_email])
    expect(mail.reply_to).to eq([sender_email])
    expect(mail.cc).to eq(["bryan@bikeindex.org", "gavin@bikeindex.org"])
  end

  def expect_notification_blocked(_sender_email)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    mail = ActionMailer::Base.deliveries.last
    expect(mail.subject).to eq("Stolen notification blocked!")
    expect(mail.to).to eq(["contact@bikeindex.org"])
  end

  it "sends customer an email" do
    expect(bike.claimed?).to be_truthy
    instance.perform(stolen_notification.id)
    expect_notification_sent(stolen_notification.sender.email)
  end

  context "second notification sent notifications" do
    let!(:stolen_notification0) { FactoryBot.create(:stolen_notification, sender: user) }
    let(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, :with_stolen_record) }
    let(:stolen_notification2) { FactoryBot.create(:stolen_notification, sender: user, bike: bike2) }
    it "sends blocked message to admin" do
      expect(stolen_notification.reload.kind).to eq "stolen_permitted"
      instance.perform(stolen_notification.id)
      expect(bike.user_id).to eq ownership.user_id
      expect(bike.current_ownership_id).to eq ownership.id
      expect(bike.status).to eq "status_stolen"
      expect(ownership.user_id).to be_present
      expect(ownership.claimed?).to be_truthy
      expect(user.reload.sent_stolen_notifications.count).to eq 2
      expect(stolen_notification.reload.receiver_id).to eq ownership.user_id
      expect(stolen_notification.sender_id).to eq user.id
      expect(stolen_notification.reload.kind).to eq "stolen_permitted"
      expect(Notification.count).to eq 1
      expect(stolen_notification2.reload.sender_id).to eq user.id
      expect(stolen_notification2.send(:unstolen_blocked?)).to be_falsey
      expect(stolen_notification2.permitted_send?).to be_falsey
      expect(stolen_notification2.notifications.count).to eq 0
      expect(stolen_notification2.send(:calculated_kind)).to eq "stolen_blocked"
      expect(stolen_notification2.kind).to eq "stolen_blocked"
      expect(bike2.reload.claimed?).to be_truthy
      expect(bike2.user&.id).to be_present
      expect {
        instance.perform(stolen_notification2.id)
      }.to change(Notification, :count).by 1
      expect_notification_blocked(stolen_notification2.sender.email)
      notification = Notification.last
      expect(notification.kind).to eq "stolen_notification_blocked"
      expect(notification.bike_id).to eq bike2.id
      expect(notification.user_id).to eq bike2.user&.id
      expect(notification.message_channel_target).to eq bike2.owner_email
      expect(notification.notifiable_id).to eq stolen_notification2.id
      expect(notification.notifiable_type).to eq "StolenNotification"
      expect(bike2.reload.messages_count).to eq 1
      expect(stolen_notification2.reload.notifications.count).to eq 1
    end
    context "with can_send_many_stolen_notifications" do
      let(:user) { FactoryBot.create(:user, can_send_many_stolen_notifications: true) }
      it "sends customer an email" do
        expect(stolen_notification.reload.kind).to eq "stolen_permitted"
        expect(stolen_notification2.reload.kind).to eq "stolen_permitted"
        expect {
          instance.perform(stolen_notification.id)
        }.to change(Notification, :count).by 1
        expect_notification_sent(stolen_notification.sender.email)

        notification = Notification.last
        expect(notification.kind).to eq "stolen_notification_sent"
        expect(notification.bike_id).to eq bike.id
        expect(notification.user_id).to eq ownership.user_id
        expect(notification.message_channel_target).to eq owner_email
        expect(notification.notifiable_id).to eq stolen_notification.id
        expect(notification.notifiable_type).to eq "StolenNotification"
        expect(ActionMailer::Base.deliveries.count).to eq 1
        expect {
          instance.perform(stolen_notification.id)
        }.to change(Notification, :count).by 0
        expect(ActionMailer::Base.deliveries.count).to eq 1
      end
    end
    context "user belongs to organization with unstolen_notifications" do
      let(:user) { FactoryBot.create(:organization_user, organization: organization) }
      it "sends customer an email" do
        notification = Notification.find_or_create_by(notifiable: stolen_notification,
          kind: "stolen_notification_sent")
        expect(notification.reload.delivery_status).to eq "delivery_pending"
        expect(notification.bike_id).to eq bike.id
        expect(notification.user_id).to eq ownership.user_id
        user.reload
        expect(user.enabled?("unstolen_notifications")).to be_truthy
        expect(stolen_notification.reload.kind).to eq "stolen_permitted"
        expect(stolen_notification2.reload.kind).to eq "stolen_permitted"
        expect {
          instance.perform(stolen_notification.id)
        }.to change(Notification, :count).by 0
        expect_notification_sent(stolen_notification.sender.email)
        expect(notification.reload.delivery_status).to eq "delivery_success"
        expect(notification.kind).to eq "stolen_notification_sent"
      end
    end
  end

  context "unstolen bike" do
    let(:bike) { FactoryBot.create(:bike, owner_email: owner_email, creator: creator) }
    it "sends to admin" do
      expect(bike.claimed?).to be_truthy
      expect(stolen_notification.permitted_send?).to be_falsey
      expect(stolen_notification.send(:unstolen_blocked?)).to be_truthy
      expect(stolen_notification.kind).to eq "unstolen_blocked"
      instance.perform(stolen_notification.id)
      expect_notification_blocked(stolen_notification.sender.email)
    end
    context "admin" do
      let(:user) { FactoryBot.create(:superuser) }
      it "sends to customer" do
        instance.perform(stolen_notification.id)
        expect_notification_sent(stolen_notification.sender.email)
        expect(stolen_notification.reload.kind).to eq "unstolen_claimed_permitted"
      end
    end
    context "user belongs to organization with unstolen_notifications" do
      let(:user) { FactoryBot.create(:organization_user, organization: organization) }
      before do
        user.reload
        expect(user.enabled?("unstolen_notifications")).to be_truthy
      end
      it "sends to customer" do
        expect(bike.reload.claimed?).to be_truthy
        instance.perform(stolen_notification.id)
        expect_notification_sent(stolen_notification.sender.email)
        expect(stolen_notification.reload.kind).to eq "unstolen_claimed_permitted"
      end
      context "bike is unclaimed" do
        let(:ownership) { FactoryBot.create(:ownership, bike: bike, creator: creator) }
        it "sends to bike creator" do
          expect(bike.claimed?).to be_falsey
          instance.perform(stolen_notification.id)
          expect_notification_sent(stolen_notification.sender.email, creator.email)
          expect(stolen_notification.reload.kind).to eq "unstolen_unclaimed_permitted"
        end
      end
    end
  end

  context "bike deleted" do
    before { stolen_notification.bike.destroy }
    it "doesn't explode" do
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
      instance.perform(stolen_notification.id)
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
    end
  end
end
