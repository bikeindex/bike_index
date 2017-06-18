require 'spec_helper'

describe Feedback do
  describe 'validations' do
    it { is_expected.to validate_presence_of :body }
    it { is_expected.to validate_presence_of :email }
    it { is_expected.to validate_presence_of :title }
    it { is_expected.to serialize :feedback_hash }
    it { is_expected.to belong_to :user }
    # it { should belong_to :application } # This is Doorkeeper::Application, not application
  end

  describe 'create' do
    it 'enqueues an email job' do
      expect do
        FactoryGirl.create(:feedback)
      end.to change(EmailFeedbackNotificationWorker.jobs, :size).by(1)
    end

    it 'enqueues an email job for delete requests' do
      expect do
        FactoryGirl.create(:feedback, feedback_type: 'bike_delete_request')
      end.to change(EmailFeedbackNotificationWorker.jobs, :size).by(1)
    end

    it "doesn't enqueue an email job for serial updates" do
      expect do
        FactoryGirl.create(:feedback, feedback_type: 'serial_update_request')
      end.to change(EmailFeedbackNotificationWorker.jobs, :size).by(0)
    end

    it "doesn't enqueue an email job for manufacturer updates" do
      expect do
        FactoryGirl.create(:feedback, feedback_type: 'manufacturer_update_request')
      end.to change(EmailFeedbackNotificationWorker.jobs, :size).by(0)
    end
  end

  describe 'lead_type' do
    context 'non-lead feedback' do
      it 'returns nil' do
        expect(Feedback.new(feedback_type: 'manufacturer_update_request').lead_type).to be_nil
      end
    end
    context 'lead type feedback' do
      it 'returns type' do
        expect(Feedback.new(feedback_type: 'lead_for_school').lead_type).to eq 'School'
      end
    end
  end
end
