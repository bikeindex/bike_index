require "rails_helper"

RSpec.describe UserLikelySpamReason, type: :model do
  describe "factory" do
    let(:user_likely_spam_reason) { FactoryBot.create(:user_likely_spam_reason) }
    let(:user) { user_likely_spam_reason.user }
    it "is valid" do
      expect(user_likely_spam_reason).to be_valid
      expect(user.likely_spam?).to be_truthy
      # It doesn't let the same thing be created for the same user
      expect(FactoryBot.build(:user_likely_spam_reason, user:)).to_not be_valid
    end
  end
end
