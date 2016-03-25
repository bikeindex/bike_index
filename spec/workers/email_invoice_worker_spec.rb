require "spec_helper"

describe EmailInvoiceWorker do
  it { should be_processed_in :notify }

  it "sends an email" do
    payment = FactoryGirl.create(:payment)
    ActionMailer::Base.deliveries = []
    EmailInvoiceWorker.new.perform(payment.id)
    ActionMailer::Base.deliveries.empty?.should be_false
  end
end
