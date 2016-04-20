require 'spec_helper'

describe Feedback do
  describe 'validations' do
    it { is_expected.to validate_presence_of :body }
    it { is_expected.to validate_presence_of :email }
    it { is_expected.to validate_presence_of :title }
    it { is_expected.to serialize :feedback_hash }
    # it { should belong_to :application } # This is Doorkeeper::Application, not application
  end

  describe 'create' do
    it "enqueues an email job" do
      expect {
        FactoryGirl.create(:feedback)
      }.to change(EmailFeedbackNotificationWorker.jobs, :size).by(1)
    end

    it "enqueues an email job for delete requests" do
      expect {
        FactoryGirl.create(:feedback, feedback_type: 'bike_delete_request')
      }.to change(EmailFeedbackNotificationWorker.jobs, :size).by(1)
    end

    it "doesn't enqueue an email job for serial updates" do
      expect {
        FactoryGirl.create(:feedback, feedback_type: 'serial_update_request')
      }.to change(EmailFeedbackNotificationWorker.jobs, :size).by(0)
    end

    it "doesn't enqueue an email job for manufacturer updates" do
      expect {
        FactoryGirl.create(:feedback, feedback_type: 'manufacturer_update_request')
      }.to change(EmailFeedbackNotificationWorker.jobs, :size).by(0)
    end
  end
end
