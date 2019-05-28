require "spec_helper"

describe EmailInvoiceWorker do
  it "sends an email" do
    payment = FactoryBot.create(:payment)
    ActionMailer::Base.deliveries = []
    EmailInvoiceWorker.new.perform(payment.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
