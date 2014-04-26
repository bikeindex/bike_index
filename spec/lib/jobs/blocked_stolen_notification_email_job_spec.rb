require 'spec_helper'

describe BlockedStolenNotificationEmailJob do

  describe :perform do
    before :each do
      @stolen_notification = FactoryGirl.create(:stolen_notification)
    end

    it "should send an email" do
      ActionMailer::Base.deliveries = []
      BlockedStolenNotificationEmailJob.perform(@stolen_notification.id)
      ActionMailer::Base.deliveries.empty?.should be_false
    end
  end
  
end
