# == Schema Information
#
# Table name: user_bans
#
#  id          :bigint           not null, primary key
#  deleted_at  :datetime
#  description :text
#  reason      :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  creator_id  :bigint
#  user_id     :bigint
#
# Indexes
#
#  index_user_bans_on_creator_id  (creator_id)
#  index_user_bans_on_user_id     (user_id)
#
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
