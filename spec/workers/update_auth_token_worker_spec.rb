require 'spec_helper'

describe UpdateAuthTokenWorker do
  it { should be_processed_in :updates }

  it "updates the auth token" do
    user = FactoryGirl.create(:user)
    old_t = user.auth_token
    UpdateAuthTokenWorker.new.perform(user.id)
    user.reload.auth_token.should_not eq(old_t)
  end

end
