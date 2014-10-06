require "spec_helper"

describe AdminContactStolenEmailJob do

  describe :perform do
    it "should send an email" do
      customer_contact = FactoryGirl.create(:customer_contact)
      ActionMailer::Base.deliveries = []
      AdminContactStolenEmailJob.perform(customer_contact.id)
      ActionMailer::Base.deliveries.should_not be_empty
    end
  end
  
end
