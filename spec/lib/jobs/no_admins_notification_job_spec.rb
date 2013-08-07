require "spec_helper"

describe NoAdminsNotificationJob do

  describe :perform do
    before :each do
      @organization = FactoryGirl.create(:organization)
    end

    it "should send an email" do
      ActionMailer::Base.deliveries = []
      NoAdminsNotificationJob.perform(@organization.id)
      ActionMailer::Base.deliveries.should_not be_empty
    end
  end
  
end
