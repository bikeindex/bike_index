require "rails_helper"

RSpec.describe EmailJobs::FeedbackNotificationJob, type: :job do
  it "sends an email" do
    feedback = FactoryBot.create(:feedback)
    ActionMailer::Base.deliveries = []
    EmailJobs::FeedbackNotificationJob.new.perform(feedback.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end
end
