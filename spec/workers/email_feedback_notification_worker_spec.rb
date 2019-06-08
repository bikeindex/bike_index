require "rails_helper"

RSpec.describe EmailFeedbackNotificationWorker, type: :job do
  it "sends an email" do
    feedback = FactoryBot.create(:feedback)
    ActionMailer::Base.deliveries = []
    EmailFeedbackNotificationWorker.new.perform(feedback.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end
end
