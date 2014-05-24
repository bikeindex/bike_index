require 'spec_helper'

describe Feedback do

  describe :validations do
    it { should validate_presence_of :body }
    it { should validate_presence_of :email }
    it { should validate_presence_of :name }
    it { should validate_presence_of :title }
    it { should serialize :feedback_hash }
  end

  describe :create do
    it "should enqueue an email job" do
      @feedback = FactoryGirl.create(:feedback)
      FeedbackNotificationEmailJob.should have_queued(@feedback.id)
    end
  end
end
