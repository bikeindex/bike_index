require "spec_helper"

describe EmailInvoiceWorker do
  it { is_expected.to be_processed_in :notify }

  it "sends an email" do
    payment = FactoryGirl.create(:payment)
    ActionMailer::Base.deliveries = []
    EmailInvoiceWorker.new.perform(payment.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
