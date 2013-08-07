require "spec_helper"

describe OrganizationInvitationEmailJob do

  describe :perform do
    before :each do
      @organization_invitation = FactoryGirl.create(:organization_invitation)
    end

    it "should send an email" do
      ActionMailer::Base.deliveries = []
      OrganizationInvitationEmailJob.perform(@organization_invitation.id)
      ActionMailer::Base.deliveries.should_not be_empty
    end
  end
  
end
