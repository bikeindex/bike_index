require "rails_helper"

RSpec.describe EmailBan, type: :model do
  describe "factory" do
    let(:email_ban) { FactoryBot.create(:email_ban, reason: :email_domain, end_at:) }
    let(:email_ban_duplicate) {}
    let(:user) { email_ban.user }
    let(:end_at) { nil }
    it "is valid" do
      expect(email_ban).to be_valid
      expect(user.reload.email_banned?).to be_truthy
      expect(email_ban.reason_humanized).to eq "domain"
      # It doesn't let the same thing be created for the same user
      expect(FactoryBot.build(:email_ban, user:, reason: :email_domain, start_at: Time.current - 1.hour))
        .to_not be_valid
      expect(FactoryBot.build(:email_ban, user:, reason: :email_duplicate)).to be_valid
    end
    context "end_at before now" do
      let(:end_at) { Time.current - 1.hour }
      it "is not email_banned" do
        expect(email_ban).to be_valid
        expect(user.reload.email_banned?).to be_falsey

        # It lets a new one be created because the old one isn't active
        expect(FactoryBot.build(:email_ban, user:, reason: :email_domain)).to_not be_valid
      end
    end
  end
end
