require "rails_helper"

RSpec.describe EmailMagicLoginLinkWorker, type: :job do
  it "sends an email" do
    user = FactoryBot.create(:user)
    ActionMailer::Base.deliveries = []
    EmailMagicLoginLinkWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
