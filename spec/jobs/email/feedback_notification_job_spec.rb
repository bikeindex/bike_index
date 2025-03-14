require "rails_helper"

RSpec.describe Email::FeedbackNotificationJob, type: :job do
  it "sends an email" do
    feedback = FactoryBot.create(:feedback)
    ActionMailer::Base.deliveries = []
    Email::FeedbackNotificationJob.new.perform(feedback.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end
end
