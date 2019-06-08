require "rails_helper"

RSpec.describe EmailNoAdminsNotificationWorker, type: :job do
  it "sends an email" do
    organization = FactoryBot.create(:organization)
    ActionMailer::Base.deliveries = []
    EmailNoAdminsNotificationWorker.new.perform(organization.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end
end
