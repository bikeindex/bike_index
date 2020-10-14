require "rails_helper"

RSpec.describe EmailDonationWorker, type: :job do
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
    end
  end

  context "donation_stolen" do
    let!(:theft_alert) { FactoryBot.create(:theft_alert_unpaid, user: user, stolen_record: stolen_record1) }
    it "sends a donation_stolen message" do
      user.reload
      expect(user.theft_alerts.count).to eq 1
      expect(instance.calculated_notification_kind(payment)).to eq "donation_stolen"
      expect(payment.notifications.count).to eq 0
      ActionMailer::Base.deliveries = []
      instance.perform(payment.id)
      expect(ActionMailer::Base.deliveries.count).to eq 1
      payment.reload
      expect(payment.notifications.count).to eq 1
      expect(payment.notifications.first.kind).to eq "donation_stolen"
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
      expect(payment_second.notifications.first.kind).to eq "donation_theft_alert"
    end
  end

  context "donation_recovered" do
    let!(:recovery) { FactoryBot.create(:stolen_record_recovered, bike: bike2, recovered_at: Time.current - 1.year) }
    it "sends a donation_stolen message if recovery is old" do
      expect(stolen_record1).to be_present
      payment.reload
      expect(instance.calculated_notification_kind(payment)).to eq "donation_stolen"
      expect(payment.notifications.count).to eq 0
      ActionMailer::Base.deliveries = []
      instance.perform(payment.id)
      expect(ActionMailer::Base.deliveries.count).to eq 1
      payment.reload
      expect(payment.notifications.count).to eq 1
      expect(payment.notifications.first.kind).to eq "donation_stolen"
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
      end
    end
  end
end
