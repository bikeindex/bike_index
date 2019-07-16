require "rails_helper"

RSpec.describe EmailConfirmationWorker, type: :job do
  it "sends a welcome email" do
    user = FactoryBot.create(:user)
    ActionMailer::Base.deliveries = []
    EmailConfirmationWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
