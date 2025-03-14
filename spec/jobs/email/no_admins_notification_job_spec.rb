require "rails_helper"

RSpec.describe Email::NoAdminsNotificationJob, type: :job do
  it "sends an email" do
    organization = FactoryBot.create(:organization)
    ActionMailer::Base.deliveries = []
    Email::NoAdminsNotificationJob.new.perform(organization.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end
end
