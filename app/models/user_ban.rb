class UserBan < ApplicationRecord
  REASON_ENUM = {
    abuse: 0,
    extortion: 1,
    known_criminal: 2,
    bad_actor: 3
  }.freeze

  acts_as_paranoid

  enum reason: REASON_ENUM

  belongs_to :user
  belongs_to :creator, class_name: "User"

  validates_presence_of :reason, :user_id

  def self.reasons
    REASON_ENUM.keys.map(&:to_s)
  end
end
