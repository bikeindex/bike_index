require "rails_helper"

RSpec.describe EmailMagicLoginLinkWorker, type: :job do
  it "sends an email" do
    user = FactoryBot.build(:user)
    user.update_auth_token("magic_link_token")
    token = user.magic_link_token
    ActionMailer::Base.deliveries = []
    described_class.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    user.reload
    expect(user.magic_link_token).to eq token
  end
  context "user doesn't have token" do
    it "adds the token for the user" do
      user = FactoryBot.create(:user)
      described_class.new.perform(user.id)
      user.reload
      expect(user.magic_link_token).to be_present
    end
  end
end
