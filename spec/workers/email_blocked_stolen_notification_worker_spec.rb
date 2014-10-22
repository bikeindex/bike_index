require 'spec_helper'

describe EmailBlockedStolenNotificationWorker do
  it { should be_processed_in :email }

  it "sends an email" do
    stolen_notification = FactoryGirl.create(:stolen_notification)
    ActionMailer::Base.deliveries = []
    EmailBlockedStolenNotificationWorker.new.perform(stolen_notification.id)
    ActionMailer::Base.deliveries.empty?.should be_false
  end
end
