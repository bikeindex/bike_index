require "rails_helper"

RSpec.describe EmailOwnershipInvitationWorker, type: :job do
  it "sends an email" do
    ownership = FactoryBot.create(:ownership)
    ActionMailer::Base.deliveries = []
    EmailOwnershipInvitationWorker.new.perform(ownership.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end

  it "does not send an email if the ownership does not exist" do
    ActionMailer::Base.deliveries = []
    EmailOwnershipInvitationWorker.new.perform(129291912)
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
