require 'spec_helper'

describe EmailOrganizationInvitationWorker do
  it { is_expected.to be_processed_in :notify }

  it 'sends an email' do
    organizationInvitation = FactoryGirl.create(:organizationInvitation)
    ActionMailer::Base.deliveries = []
    EmailOrganizationInvitationWorker.new.perform(organizationInvitation.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end
end
