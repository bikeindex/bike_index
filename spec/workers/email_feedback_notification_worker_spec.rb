require "spec_helper"

describe EmailFeedbackNotificationWorker do
  it { is_expected.to be_processed_in :notify }

  it "sends an email" do
    feedback = FactoryGirl.create(:feedback)
    ActionMailer::Base.deliveries = []
    EmailFeedbackNotificationWorker.new.perform(feedback.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end
end
