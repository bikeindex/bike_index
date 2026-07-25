require "rails_helper"

RSpec.describe UserBan, type: :model do
  describe "nested create" do
    let(:user) { FactoryBot.create(:user) }
    let(:admin) { FactoryBot.create(:superuser) }
    it "is valid" do
      user.update(banned: true, user_ban_attributes: {creator: admin, reason: :abuse})
      expect(user.user_ban).to be_valid
      expect(user.user_ban.creator&.id).to eq admin.id
      expect(user.user_ban.reason).to eq "abuse"
    end
  end

  describe "update_user_on_create" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:) }
    let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, item: bike) }
    it "bans the user and marks bikes likely_spam (not deleted), pulling listings" do
      UserBan.create(user:, reason: :seo_spam)
      expect(user.reload.banned?).to be_truthy
      expect(bike.reload.likely_spam).to be_truthy
      expect(bike.deleted_at).to be_blank
      expect(marketplace_listing.reload.status).to eq "removed"
    end
  end

  describe "reason_humanized" do
    it "humanizes by default" do
      expect(UserBan.reason_humanized("known_criminal")).to eq "Known criminal"
    end
    it "uses the override for seo_spam" do
      expect(UserBan.new(reason: :seo_spam).reason_humanized).to eq "SEO SPAM"
    end
    it "is nil when blank" do
      expect(UserBan.reason_humanized(nil)).to be_nil
    end
  end
end
