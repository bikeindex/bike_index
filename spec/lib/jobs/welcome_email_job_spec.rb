require 'spec_helper'

describe WelcomeEmailJob do
  describe :perform do
    it "should send a welcome email" do
      user = FactoryGirl.create(:user)
      WelcomeEmailJob.perform(user.id)
      ActionMailer::Base.deliveries.empty?.should be_false
    end
  end
end
