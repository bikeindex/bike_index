require 'spec_helper'

describe UpdateAuthTokenWorker do
  it { is_expected.to be_processed_in :updates }

  it "updates the auth token" do
    user = FactoryGirl.create(:user)
    old_t = user.auth_token
    UpdateAuthTokenWorker.new.perform(user.id)
    expect(user.reload.auth_token).not_to eq(old_t)
  end

end
