require "spec_helper"

describe FeedbackNotificationEmailJob do

  describe :perform do
    before :each do 
      @feedback = FactoryGirl.create(:feedback)
    end
    it "should send an email" do
      ActionMailer::Base.deliveries = []
      FeedbackNotificationEmailJob.perform(@feedback.id)
      ActionMailer::Base.deliveries.should_not be_empty
    end
  end
  
end
