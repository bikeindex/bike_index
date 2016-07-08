require 'spec_helper'

describe EmailPartialRegistrationWorker do
  it { is_expected.to be_processed_in :notify }

  it 'sends a partial registration email' do
    b_param = FactoryGirl.create(:b_param)
    EmailPartialRegistrationWorker.new.perform(b_param.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
