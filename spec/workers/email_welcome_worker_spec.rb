require 'spec_helper'

describe EmailWelcomeWorker do
  it { is_expected.to be_processed_in :notify }

  it 'enqueues listing ordering job' do
    user = FactoryGirl.create(:user)
    EmailWelcomeWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
