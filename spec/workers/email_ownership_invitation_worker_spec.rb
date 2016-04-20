require "spec_helper"

describe EmailOwnershipInvitationWorker do
  it { is_expected.to be_processed_in :notify }

  it "sends an email" do
    ownership = FactoryGirl.create(:ownership)
    ActionMailer::Base.deliveries = []
    EmailOwnershipInvitationWorker.new.perform(ownership.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end
end
