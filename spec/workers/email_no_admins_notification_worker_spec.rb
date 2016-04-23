require 'spec_helper'

describe EmailNoAdminsNotificationWorker do
  it { is_expected.to be_processed_in :notify }

  it 'sends an email' do
    organization = FactoryGirl.create(:organization)
    ActionMailer::Base.deliveries = []
    EmailNoAdminsNotificationWorker.new.perform(organization.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end
end
