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
end
