require 'spec_helper'

describe EmailOwnershipInvitationWorker do
  it { is_expected.to be_processed_in :notify }

  it 'sends an email' do
    ownership = FactoryGirl.create(:ownership)
    ActionMailer::Base.deliveries = []
    EmailOwnershipInvitationWorker.new.perform(ownership.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end

  it 'does not send an email if the ownership does not exist' do
    ActionMailer::Base.deliveries = []
    EmailOwnershipInvitationWorker.new.perform(129291912)
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
