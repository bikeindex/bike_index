# == Schema Information
#
# Table name: user_bans
# Database name: primary
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
class UserBan < ApplicationRecord
  REASON_ENUM = {
    spamming: 4,
    abuse: 0,
    extortion: 1,
    known_criminal: 2,
    bad_actor: 3
  }.freeze

  acts_as_paranoid

  enum :reason, REASON_ENUM

  belongs_to :user
  belongs_to :creator, class_name: "User"

  validates_presence_of :reason, :user_id

  after_commit :update_user_on_create, on: :create

  def self.reasons
    REASON_ENUM.keys.map(&:to_s)
  end

  def update_user_on_create
    return if id.blank?

    # Sign them out
    user.update_auth_token("auth_token")
    # Remove their marketplace listing (so that they don't show up anymore)
    user.marketplace_listings.for_sale.each { it.update(status: :removed) }
  end
end
