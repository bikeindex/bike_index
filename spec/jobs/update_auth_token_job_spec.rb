require "rails_helper"

RSpec.describe UpdateAuthTokenJob, type: :job do
  let(:subject) { UpdateAuthTokenJob }

  it "is the correct queue" do
    expect(subject.sidekiq_options["queue"]).to eq "high_priority"
  end

  it "updates the auth token" do
    user = FactoryBot.create(:user)
    old_t = user.auth_token
    UpdateAuthTokenJob.new.perform(user.id)
    expect(user.reload.auth_token).not_to eq(old_t)
  end
end
