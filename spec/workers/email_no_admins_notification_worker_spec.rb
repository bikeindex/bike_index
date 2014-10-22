require "spec_helper"

describe EmailNoAdminsNotificationWorker do
  it { should be_processed_in :email }

  it "should send an email" do
    organization = FactoryGirl.create(:organization)
    ActionMailer::Base.deliveries = []
    EmailNoAdminsNotificationWorker.new.perform(organization.id)
    ActionMailer::Base.deliveries.should_not be_empty
  end
end