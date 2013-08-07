require 'spec_helper'

describe Feedback do

  describe :create do
    it "should enqueue an email job" do
      @feedback = FactoryGirl.create(:feedback)
      FeedbackNotificationEmailJob.should have_queued(@feedback.id)
    end
  end
end
