require "spec_helper"

describe AdminStolenEmailJob do

  describe :perform do
    it "should send an email" do
      customer_contact = FactoryGirl.create(:customer_contact)
      ActionMailer::Base.deliveries = []
      AdminStolenEmailJob.perform(customer_contact.id)
      ActionMailer::Base.deliveries.should_not be_empty
    end

    it "should not send an email if the stolen bike has receive_notifications false" do
      stolen_record = FactoryGirl.create(:stolen_record, receive_notifications: false)
      stolen_record.bike.update_attribute :stolen, true
      customer_contact = FactoryGirl.create(:customer_contact, bike: stolen_record.bike)
      ActionMailer::Base.deliveries = []
      AdminStolenEmailJob.perform(customer_contact.id)
      ActionMailer::Base.deliveries.should be_empty
    end
  end
  
end
