require 'spec_helper'

describe EmailWelcomeWorker do
  it { should be_processed_in :email }

  it "enqueues listing ordering job" do
    user = FactoryGirl.create(:user)
    EmailWelcomeWorker.new.perform(user.id)
    ActionMailer::Base.deliveries.empty?.should be_false    
  end

end
