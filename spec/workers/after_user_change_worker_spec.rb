require 'spec_helper'

describe AfterUserChangeWorker do
  it { should be_processed_in :afterwards }

  it 'Calls webhook runner for the user' do
    user = FactoryGirl.create(:user)
    expect_any_instance_of(WebhookRunner).to receive(:after_user_update).with(user.id).once
    AfterUserChangeWorker.new.perform(user.id)
  end
end
