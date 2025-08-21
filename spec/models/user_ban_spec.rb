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
end
