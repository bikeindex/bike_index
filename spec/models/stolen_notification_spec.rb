require 'spec_helper'

describe StolenNotification do

  describe :create do
    it "should enqueue an email job" do
      @stolen_notification = FactoryGirl.create(:stolen_notification)
      StolenNotificationEmailJob.should have_queued(@stolen_notification.id)
    end
  end
end
