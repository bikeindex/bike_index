require "spec_helper"

describe EmailBikeTokenInvitationWorker do
  it { should be_processed_in :email }

  it "sends an email" do
    bike_token_invitation = FactoryGirl.create(:bike_token_invitation)
    ActionMailer::Base.deliveries = []
    EmailBikeTokenInvitationWorker.new.perform(bike_token_invitation.id)
    ActionMailer::Base.deliveries.should_not be_empty
  end

end
