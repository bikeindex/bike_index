require "spec_helper"

describe EmailFeedbackNotificationWorker do
  it { should be_processed_in :email }

  it "sends an email" do
    feedback = FactoryGirl.create(:feedback)
    ActionMailer::Base.deliveries = []
    EmailFeedbackNotificationWorker.new.perform(feedback.id)
    ActionMailer::Base.deliveries.should_not be_empty
  end
end
