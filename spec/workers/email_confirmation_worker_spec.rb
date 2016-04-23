require 'spec_helper'

describe EmailConfirmationWorker do
  it { is_expected.to be_processed_in :notify }

  it 'sends a welcome email' do
    user = FactoryGirl.create(:user)
    EmailConfirmationWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
