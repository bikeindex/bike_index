require "rails_helper"

RSpec.describe EmailDonationJob, type: :job do
  let(:subject) { described_class }
  let(:instance) { described_class.new }
  let(:payment) { FactoryBot.create(:payment, kind: "donation") }
  let(:user) { payment.user }
  let(:bike1) { FactoryBot.create(:bike, :with_ownership_claimed, user: user) }
  let(:stolen_record1) { FactoryBot.create(:stolen_record, bike: bike1) }
  let(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, user: user) }

  it "sends an email" do
    expect(payment.notifications.count).to eq 0
    ActionMailer::Base.deliveries = []
    instance.perform(payment.id)
    expect(ActionMailer::Base.deliveries.count).to eq 1
    payment.reload
    expect(payment.notifications.count).to eq 1
    expect(payment.notifications.first.kind).to eq "donation_standard"
    expect(payment.notifications.first.bike_id).to be_blank
    expect(payment.notifications.first.message_channel_target).to eq user.email
    # But it doesn't send again
    instance.perform(payment.id)
    expect(ActionMailer::Base.deliveries.count).to eq 1
  end

  context "not a donation" do
    let(:payment) { FactoryBot.create(:payment, kind: "payment") }
    it "does not send" do
      expect(payment.notifications.count).to eq 0
      ActionMailer::Base.deliveries = []
      instance.perform(payment.id)
      expect(ActionMailer::Base.deliveries.count).to eq 0
      payment.reload
      expect(payment.notifications.count).to eq 0
    end
  end

  context "donation_second" do
    let!(:payment_second) { FactoryBot.create(:payment, kind: "donation", user: user) }
    it "sends a donation_second message" do
      expect(instance.calculated_notification_kind(payment)).to eq "donation_standard"
      expect(instance.calculated_notification_kind(payment_second)).to eq "donation_second"
      expect(payment_second.notifications.count).to eq 0
      ActionMailer::Base.deliveries = []
      instance.perform(payment_second.id)
      expect(ActionMailer::Base.deliveries.count).to eq 1
      payment_second.reload
      expect(payment_second.notifications.count).to eq 1
      expect(payment_second.notifications.first.kind).to eq "donation_second"
      expect(payment_second.notifications.first.bike_id).to be_blank
    end
  end

  context "donation_stolen" do
    let!(:theft_alert) { FactoryBot.create(:theft_alert_unpaid, user: user, stolen_record: stolen_record1) }
    it "sends a donation_stolen message" do
      user.reload
      expect(user.theft_alerts.count).to eq 1
      expect(instance.bike_for_notification(payment, "donation_stolen")&.id).to eq bike1.id
      expect(instance.calculated_notification_kind(payment)).to eq "donation_stolen"
      expect(payment.notifications.count).to eq 0
      ActionMailer::Base.deliveries = []
      instance.perform(payment.id)
      expect(ActionMailer::Base.deliveries.count).to eq 1
      payment.reload
      expect(payment.notifications.count).to eq 1
      expect(payment.notifications.first.kind).to eq "donation_stolen"
      expect(payment.notifications.first.bike_id).to be_present
      expect(payment.notifications.first.bike_id).to eq bike1.id
    end
    context "older stolen record" do
      let(:stolen_record2) { FactoryBot.create(:stolen_record, bike: bike2, date_stolen: Time.current - 2.weeks) }
      it "is the more recent stolen_record" do
        user.reload
        expect(user.theft_alerts.count).to eq 1
        expect(stolen_record2.date_stolen).to be < stolen_record1.date_stolen
        expect(instance.bike_for_notification(payment, "donation_stolen")&.id).to eq bike1.id
        expect(instance.calculated_notification_kind(payment)).to eq "donation_stolen"
        expect(payment.notifications.count).to eq 0
        ActionMailer::Base.deliveries = []
        instance.perform(payment.id)
        expect(ActionMailer::Base.deliveries.count).to eq 1
        payment.reload
        expect(payment.notifications.count).to eq 1
        expect(payment.notifications.first.kind).to eq "donation_stolen"
        expect(payment.notifications.first.bike_id).to be_present
        expect(payment.notifications.first.bike_id).to eq bike1.id
      end
    end
  end

  context "donation_theft_alert" do
    let!(:payment_second) { FactoryBot.create(:payment, kind: "donation", user: user) }
    let!(:theft_alert) { FactoryBot.create(:theft_alert_paid, user: user, stolen_record: stolen_record1) }
    it "sends a donation_theft_alert message" do
      payment_second.reload
      user.reload
      expect(instance.calculated_notification_kind(payment_second)).to eq "donation_theft_alert"
      expect(payment_second.notifications.count).to eq 0
      ActionMailer::Base.deliveries = []
      instance.perform(payment_second.id)
      expect(ActionMailer::Base.deliveries.count).to eq 1
      payment_second.reload
      expect(payment_second.notifications.count).to eq 1
      notification = payment_second.notifications.first
      expect(notification.kind).to eq "donation_theft_alert"
      expect(notification.bike_id).to be_present
      expect(notification.bike_id).to eq theft_alert.bike&.id
      expect(notification.theft_alert?).to be_falsey
      expect(notification.donation?).to be_truthy
    end
  end

  context "donation_recovered" do
    let!(:recovery) { FactoryBot.create(:stolen_record_recovered, bike: bike2, recovered_at: Time.current - 1.year) }
    it "sends a donation_stolen message if recovery is old" do
      expect(stolen_record1).to be_present
      payment.reload
      expect(instance.bike_for_notification(payment, "donation_stolen")&.id).to eq bike1.id
      expect(instance.calculated_notification_kind(payment)).to eq "donation_stolen"
      expect(payment.notifications.count).to eq 0
      ActionMailer::Base.deliveries = []
      instance.perform(payment.id)
      expect(ActionMailer::Base.deliveries.count).to eq 1
      payment.reload
      expect(payment.notifications.count).to eq 1
      expect(payment.notifications.first.kind).to eq "donation_stolen"
      expect(payment.notifications.first.bike_id).to be_present
      expect(payment.notifications.first.bike_id).to eq stolen_record1.bike&.id
    end
    context "with active theft alert" do
      let!(:theft_alert) { FactoryBot.create(:theft_alert_begun, user: user) }
      let!(:recovery2) { FactoryBot.create(:stolen_record_recovered, bike: bike2, recovered_at: Time.current - 1.week) }
      it "sends a donation_recovered message" do
        expect(stolen_record1).to be_present
        user.reload
        expect(user.bikes.pluck(:id)).to match_array([bike1.id, bike2.id])
        expect(instance.calculated_notification_kind(payment)).to eq "donation_recovered"
        expect(payment.notifications.count).to eq 0
        ActionMailer::Base.deliveries = []
        instance.perform(payment.id)
        expect(ActionMailer::Base.deliveries.count).to eq 1
        payment.reload
        expect(payment.notifications.count).to eq 1
        expect(payment.notifications.first.kind).to eq "donation_recovered"
        expect(payment.notifications.first.bike_id).to be_present
        expect(payment.notifications.first.bike_id).to eq recovery2.bike&.id
      end
    end
  end
end
