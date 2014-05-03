require 'spec_helper'

describe LightspeedNotificationEmailJob do

  describe :perform do
    before :each do
      @organization = FactoryGirl.create(:organization)
      @api_key = 'some key or something'
    end

    it "should send an email" do
      ActionMailer::Base.deliveries = []
      LightspeedNotificationEmailJob.perform(@organization.id, @api_key)
      ActionMailer::Base.deliveries.empty?.should be_false
    end
  end
  
end
