require "spec_helper"

describe BikeTokenInvitationEmailJob do

  describe :perform do
    before :each do
      @bike_token_invitation = FactoryGirl.create(:bike_token_invitation)
    end

    it "should send an email" do
      ActionMailer::Base.deliveries = []
      BikeTokenInvitationEmailJob.perform(@bike_token_invitation.id)
      ActionMailer::Base.deliveries.should_not be_empty
    end
  end
  
end
