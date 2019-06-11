require "rails_helper"

RSpec.describe AfterUserChangeWorker, type: :job do
  it "Calls webhook runner for the user" do
    user = FactoryBot.create(:user)
    expect_any_instance_of(WebhookRunner).to receive(:after_user_update).with(user.id).once
    AfterUserChangeWorker.new.perform(user.id)
  end
end
