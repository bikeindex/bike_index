require "spec_helper"

describe EmailConfirmationWorker do
  it "sends a welcome email" do
    user = FactoryBot.create(:user)
    EmailConfirmationWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
