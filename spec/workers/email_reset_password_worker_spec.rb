require 'spec_helper'

describe EmailResetPasswordWorker do
  it { should be_processed_in :email }

  it "sends a password_reset email" do
    user = FactoryGirl.create(:user)
    EmailResetPasswordWorker.new.perform(user.id)
    ActionMailer::Base.deliveries.empty?.should be_false
  end
end
