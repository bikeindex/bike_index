require "spec_helper"

describe EmailFeedbackNotificationWorker do
  it "sends an email" do
    feedback = FactoryBot.create(:feedback)
    ActionMailer::Base.deliveries = []
    EmailFeedbackNotificationWorker.new.perform(feedback.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end
end
