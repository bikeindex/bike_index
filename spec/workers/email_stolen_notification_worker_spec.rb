require 'spec_helper'

describe EmailStolenNotificationWorker do
  let(:subject) { EmailStolenNotificationWorker }
  let(:instance) { subject.new }
  it { is_expected.to be_processed_in :notify }

  let(:creator) { FactoryBot.create(:user_confirmed) }
  let(:owner_email) { "targetbike@example.org" }
  let(:user) { FactoryBot.create(:user) }
  let(:bike) { FactoryBot.create(:stolen_bike, owner_email: owner_email, creator: creator) }
  let!(:ownership) { FactoryBot.create(:ownership_claimed, bike: bike, creator: creator) }
  let!(:stolen_notification) { FactoryBot.create(:stolen_notification, bike: bike, sender: user) }
  let(:organization) do
    o = FactoryBot.create(:organization)
    o.update_attribute :paid_feature_slugs, %w[unstolen_notifications]
    o
  end
  before { ActionMailer::Base.deliveries = [] }

  def expect_notification_sent(override_email = nil)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    mail = ActionMailer::Base.deliveries.last
    expect(mail.subject).to eq("Stolen bike contact")
    expect(mail.to).to eq([override_email || owner_email, 'lily@bikeindex.org', 'bryan@bikeindex.org'])
  end

  def expect_notification_blocked
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    mail = ActionMailer::Base.deliveries.last
    expect(mail.subject).to eq("Stolen notification blocked!")
    expect(mail.to).to eq(["bryan@bikeindex.org"])
  end

  it "sends customer an email" do
    expect(bike.claimed?).to be_truthy
    instance.perform(stolen_notification.id)
    expect_notification_sent
  end

  context "second notification sent notifications" do
    let!(:stolen_notification2) { FactoryBot.create(:stolen_notification, sender: user) }
    it "sends blocked message to admin" do
      instance.perform(stolen_notification.id)
      expect_notification_blocked
    end
    context "with can_send_many_stolen_notifications" do
      let(:user) { FactoryBot.create(:user, can_send_many_stolen_notifications: true) }
      it "sends customer an email" do
        instance.perform(stolen_notification.id)
        expect_notification_sent
      end
    end
    context "user belongs to organization with unstolen_notifications" do
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      it "sends customer an email" do
        user.reload
        expect(user.send_unstolen_notifications?).to be_truthy
        instance.perform(stolen_notification.id)
        expect_notification_sent
      end
    end
  end

  context "unstolen bike" do
    let(:bike) { FactoryBot.create(:bike, owner_email: owner_email, creator: creator) }
    it "sends to admin" do
      expect(bike.claimed?).to be_truthy
      expect(stolen_notification.permitted_send?).to be_falsey
      expect(stolen_notification.unstolen_blocked?).to be_truthy
      instance.perform(stolen_notification.id)
      expect_notification_blocked
    end
    context "admin" do
      let(:user) { FactoryBot.create(:admin) }
      it "sends to customer" do
        instance.perform(stolen_notification.id)
        expect_notification_sent
      end
    end
    context "user belongs to organization with unstolen_notifications" do
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      before do
        user.reload
        expect(user.send_unstolen_notifications?).to be_truthy
      end
      it "sends to customer" do
        instance.perform(stolen_notification.id)
        expect_notification_sent
      end
      context "bike is unclaimed" do
        let(:ownership) { FactoryBot.create(:ownership, bike: bike, creator: creator) }
        it "sends to bike creator" do
          expect(bike.claimed?).to be_falsey
          instance.perform(stolen_notification.id)
          expect_notification_sent(creator.email)
        end
      end
    end
  end
end
