require "spec_helper"

describe EmailAdminContactStolenWorker do
  it { should be_processed_in :email }

  describe :perform do
    it "sends an email" do
      customer_contact = FactoryGirl.create(:customer_contact)
      ActionMailer::Base.deliveries = []
      EmailAdminContactStolenWorker.new.perform(customer_contact.id)
      ActionMailer::Base.deliveries.should_not be_empty
    end
  end
  
end
