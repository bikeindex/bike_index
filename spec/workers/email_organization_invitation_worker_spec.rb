require "spec_helper"

describe EmailOrganizationInvitationWorker do
  it { should be_processed_in :email }


  it "sends an email" do
    organization_invitation = FactoryGirl.create(:organization_invitation)
    ActionMailer::Base.deliveries = []
    EmailOrganizationInvitationWorker.new.perform(organization_invitation.id)
    ActionMailer::Base.deliveries.should_not be_empty
  end
end
