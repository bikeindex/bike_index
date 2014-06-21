require 'spec_helper'

describe StolenNotification do

  describe :validations do
    it { should belong_to :bike }
    it { should belong_to :sender }
    it { should belong_to :receiver }
    it { should validate_presence_of :sender }
    it { should validate_presence_of :bike }
    it { should validate_presence_of :message }
    it { should serialize :send_dates }
  end

  describe :create do
    it "should enqueue an email job, and enque a second one if user has permission to send multiple" do
      user = FactoryGirl.create(:user, can_send_many_stolen_notifications: true)
      stolen_notification = FactoryGirl.create(:stolen_notification, sender: user)
      stolen_notification.send_dates.should eq([])
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
