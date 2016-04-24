require 'spec_helper'

describe EmailOrganizationInvitationWorker do
  it { is_expected.to be_processed_in :notify }

  it 'sends an email' do
    organization_invitation = FactoryGirl.create(:organization_invitation)
    ActionMailer::Base.deliveries = []
    EmailOrganizationInvitationWorker.new.perform(organization_invitation.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end
end
