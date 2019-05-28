require "spec_helper"

describe EmailWelcomeWorker do
  it "enqueues listing ordering job" do
    user = FactoryBot.create(:user)
    EmailWelcomeWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
