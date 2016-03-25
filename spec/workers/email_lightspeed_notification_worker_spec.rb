require 'spec_helper'

describe EmailLightspeedNotificationWorker do
  it { should be_processed_in :notify }

  it "sends an email" do
    organization = FactoryGirl.create(:organization)
    api_key = 'some key or something'
    ActionMailer::Base.deliveries = []
    EmailLightspeedNotificationWorker.new.perform(organization.id, api_key)
    ActionMailer::Base.deliveries.empty?.should be_false
  end
end
