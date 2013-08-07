require 'spec_helper'

describe ResetPasswordEmailJob do
  describe :perform do
    it "should send a password_reset email" do
      user = FactoryGirl.create(:user)
      ResetPasswordEmailJob.perform(user.id)
      ActionMailer::Base.deliveries.empty?.should be_false
    end
  end
end
