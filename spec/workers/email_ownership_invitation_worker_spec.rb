require "spec_helper"

describe EmailOwnershipInvitationWorker do
  it { should be_processed_in :email }

  it "should send an email" do
    ownership = FactoryGirl.create(:ownership)
    ActionMailer::Base.deliveries = []
    EmailOwnershipInvitationWorker.new.perform(ownership.id)
    ActionMailer::Base.deliveries.should_not be_empty
  end
end