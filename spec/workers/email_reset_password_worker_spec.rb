require "rails_helper"

RSpec.describe EmailResetPasswordWorker, type: :job do
  it "sends a password_reset email" do
    user = FactoryBot.build(:user)
    user.update_auth_token("password_reset_token")
    token = user.password_reset_token
    ActionMailer::Base.deliveries = []
    EmailResetPasswordWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    user.reload
    expect(user.password_reset_token).to eq token
  end
  context "user doesn't have token" do
    it "raises an error" do
      user = FactoryBot.create(:user)
      expect(user.password_reset_token).to be_blank
      ActionMailer::Base.deliveries = []
      expect {
        described_class.new.perform(user.id)
      }.to raise_error(/#{user.id}.*password_reset_token/)
      user.reload
      expect(user.magic_link_token).to be_blank
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
    end
  end
end
