require "spec_helper"

describe AdditionalEmailConfirmationWorker do
  it "sends a confirm your additional email, email" do
    user_email = FactoryBot.create(:user_email)
    AdditionalEmailConfirmationWorker.new.perform(user_email.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
