require "spec_helper"

describe EmailOwnershipInvitationWorker do
  it { should be_processed_in :notify }

  it "sends an email" do
    ownership = FactoryGirl.create(:ownership)
    ActionMailer::Base.deliveries = []
    EmailOwnershipInvitationWorker.new.perform(ownership.id)
    ActionMailer::Base.deliveries.should_not be_empty
  end
end
