require "spec_helper"

describe UpdateAuthTokenWorker do
  let(:subject) { UpdateAuthTokenWorker }

  it "is the correct queue" do
    expect(subject.sidekiq_options["queue"]).to eq "high_priority"
  end

  it "updates the auth token" do
    user = FactoryBot.create(:user)
    old_t = user.auth_token
    UpdateAuthTokenWorker.new.perform(user.id)
    expect(user.reload.auth_token).not_to eq(old_t)
  end
end
