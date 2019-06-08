require "rails_helper"

RSpec.describe EmailWelcomeWorker, type: :job do
  it "enqueues listing ordering job" do
    user = FactoryBot.create(:user)
    EmailWelcomeWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
