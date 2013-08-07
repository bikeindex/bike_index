require 'spec_helper'

describe ConfirmationEmailJob do
  describe :perform do
    it "should send a welcome email" do
      user = FactoryGirl.create(:user)
      ConfirmationEmailJob.perform(user.id)
      ActionMailer::Base.deliveries.empty?.should be_false
    end
  end
end
