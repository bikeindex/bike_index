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
    it "enqueues an email job, and enque a second one if user has permission to send multiple" do
      user = FactoryGirl.create(:user, can_send_many_stolen_notifications: true)
      expect {
        FactoryGirl.create(:stolen_notification, sender: user)
      }.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
      stolen_notification = StolenNotification.where(sender_id: user.id).first
      stolen_notification.send_dates.should eq([])
      expect {
        stolen_notification2 = FactoryGirl.create(:stolen_notification, sender: user)
      }.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
    end
    it "does not enqueue an StolenNotificationEmailJob if user doesn't have permission" do 
      user = FactoryGirl.create(:user)
      expect {
        stolen_notification = FactoryGirl.create(:stolen_notification, sender: user)
      }.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
      
      expect {
        stolen_notification2 = FactoryGirl.create(:stolen_notification, sender: user)
      }.to change(EmailBlockedStolenNotificationWorker.jobs, :size).by(1)
    end
  end

end
