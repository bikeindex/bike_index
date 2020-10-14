require "rails_helper"

RSpec.describe EmailDonationWorker, type: :job do
  it "sends an email" do
    payment = FactoryBot.create(:payment, kind: "donation")
    expect(payment.notifications.count).to eq 0
    ActionMailer::Base.deliveries = []
    EmailDonationWorker.new.perform(payment.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    payment.reload
    expect(payment.notifications.count).to eq 1
  end

  context "not a donation" do
    it "does not send"
  end

  context "donation_second" do
    it "sends a donation_second message"
  end

  context "donation_stolen" do
    it "sends a donation_stolen message"
  end

  context "donation_recovered" do
    it "sends a donation_recovered message"
  end

  context "donation_theft_alert" do
    it "sends a donation_theft_alert message"
  end
end
