require "spec_helper"

describe EmailOrganizationInvitationWorker do
  it "sends an email" do
    organization_invitation = FactoryBot.create(:organization_invitation)
    ActionMailer::Base.deliveries = []
    EmailOrganizationInvitationWorker.new.perform(organization_invitation.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end
end
