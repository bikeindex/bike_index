require "rails_helper"

RSpec.describe EmailJobs::LightspeedNotificationJob, type: :job do
  it "sends an email" do
    organization = FactoryBot.create(:organization)
    api_key = "some key or something"
    ActionMailer::Base.deliveries = []
    EmailJobs::LightspeedNotificationJob.new.perform(organization.id, api_key)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
