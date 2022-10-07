class UserBan < ApplicationRecord
  REASON_ENUM = {
    something: 0
  }.freeze

  acts_as_paranoid

  enum reason: REASON_ENUM

  belongs_to :user
  belongs_to :creator, class_name: "User"

  validates_presence_of :reason, :user_id, :creator_id
end
