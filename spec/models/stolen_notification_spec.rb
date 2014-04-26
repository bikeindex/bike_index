require 'spec_helper'

describe StolenNotification do

  describe :create do
    it "should enqueue an email job, and enque a second one if user has permission to send multiple" do
      user = FactoryGirl.create(:user, can_send_many_stolen_notifications: true)
      stolen_notification = FactoryGirl.create(:stolen_notification, sender: user)
      StolenNotificationEmailJob.should have_queued(stolen_notification.id)
      stolen_notification2 = FactoryGirl.create(:stolen_notification, sender: user)
      StolenNotificationEmailJob.should have_queued(stolen_notification2.id)
    end
    it "should not enqueue an StolenNotificationEmailJob if user doesn't have permission" do 
      user = FactoryGirl.create(:user)
      stolen_notification = FactoryGirl.create(:stolen_notification, sender: user)
      StolenNotificationEmailJob.should have_queued(stolen_notification.id)
      stolen_notification2 = FactoryGirl.create(:stolen_notification, sender: user)
      BlockedStolenNotificationEmailJob.should have_queued(stolen_notification2.id)
    end
  end

end
