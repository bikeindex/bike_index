require "rails_helper"

RSpec.describe EmailResetPasswordWorker, type: :job do
  it "sends a password_reset email" do
    user = FactoryBot.create(:user)
    EmailResetPasswordWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
