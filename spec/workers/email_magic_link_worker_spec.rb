require "rails_helper"

RSpec.describe EmailMagicLoginLinkWorker, type: :job do
  it "sends an email" do
    user = FactoryBot.build(:user)
    user.update_auth_token("magic_link_token")
    ActionMailer::Base.deliveries = []
    described_class.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
  context "user doesn't have token" do
    it "raises an error" do
      user = FactoryBot.create(:user)
      expect { described_class.new.perform(user.id) }.to raise_error(/missing.*token/i)
    end
  end
end
