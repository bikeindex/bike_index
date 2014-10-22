require 'spec_helper'

describe EmailConfirmationWorker do
  it { should be_processed_in :email }
  
  it "should send a welcome email" do
    user = FactoryGirl.create(:user)
    EmailConfirmationWorker.new.perform(user.id)
    ActionMailer::Base.deliveries.empty?.should be_false
  end
end