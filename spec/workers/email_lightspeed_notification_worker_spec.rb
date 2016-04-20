require 'spec_helper'

describe EmailLightspeedNotificationWorker do
  it { is_expected.to be_processed_in :notify }

  it "sends an email" do
    organization = FactoryGirl.create(:organization)
    api_key = 'some key or something'
    ActionMailer::Base.deliveries = []
    EmailLightspeedNotificationWorker.new.perform(organization.id, api_key)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
