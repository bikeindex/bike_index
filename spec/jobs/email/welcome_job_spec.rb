require "rails_helper"

RSpec.describe Email::WelcomeJob, type: :job do
  it "enqueues listing ordering job" do
    user = FactoryBot.create(:user)
    ActionMailer::Base.deliveries = []
    Email::WelcomeJob.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
