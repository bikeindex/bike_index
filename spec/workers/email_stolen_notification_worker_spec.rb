require 'spec_helper'

describe EmailStolenNotificationWorker do
  it { should be_processed_in :notify }

  it "sends an email" do
    stolen_notification = FactoryGirl.create(:stolen_notification)
    ActionMailer::Base.deliveries = []
    EmailStolenNotificationWorker.new.perform(stolen_notification.id)
    ActionMailer::Base.deliveries.empty?.should be_false
  end
  
end
