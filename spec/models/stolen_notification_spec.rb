require 'spec_helper'

describe StolenNotification do
  describe 'validations' do
    it { is_expected.to belong_to :bike }
    it { is_expected.to belong_to :sender }
    it { is_expected.to belong_to :receiver }
    it { is_expected.to validate_presence_of :sender }
    it { is_expected.to validate_presence_of :bike }
    it { is_expected.to validate_presence_of :message }
    it { is_expected.to serialize :send_dates }
  end

  describe 'create' do
    it 'enqueues an email job, and enque a second one if user has permission to send multiple' do
      user = FactoryGirl.create(:user, can_send_many_stolenNotifications: true)
      expect do
        FactoryGirl.create(:stolenNotification, sender: user)
      end.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
      stolenNotification = StolenNotification.where(sender_id: user.id).first
      expect(stolenNotification.send_dates).to eq([])
      expect do
        stolenNotification2 = FactoryGirl.create(:stolenNotification, sender: user)
      end.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
    end
    it "does not enqueue an StolenNotificationEmailJob if user doesn't have permission" do
      user = FactoryGirl.create(:user)
      expect do
        stolenNotification = FactoryGirl.create(:stolenNotification, sender: user)
      end.to change(EmailStolenNotificationWorker.jobs, :size).by(1)

      expect do
        stolenNotification2 = FactoryGirl.create(:stolenNotification, sender: user)
      end.to change(EmailBlockedStolenNotificationWorker.jobs, :size).by(1)
    end
  end

  describe 'default_subject' do
    it 'default subject' do
      expect(StolenNotification.new.default_subject).to eq('Stolen bike contact')
    end
  end
end
