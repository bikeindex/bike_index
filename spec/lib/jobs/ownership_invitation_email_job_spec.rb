require "spec_helper"

describe OwnershipInvitationEmailJob do

  describe :perform do
    before :each do
      @ownership = FactoryGirl.create(:ownership)
    end

    it "should send an email" do
      ActionMailer::Base.deliveries = []
      OwnershipInvitationEmailJob.perform(@ownership.id)
      ActionMailer::Base.deliveries.should_not be_empty
    end
  end
  
end
