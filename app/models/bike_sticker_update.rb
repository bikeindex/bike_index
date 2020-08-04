class BikeStickerUpdate < ApplicationRecord
  KIND_ENUM = {initial_assignment: 0, reassignment: 1, unassignment: 2, failed_assignment: 3}.freeze
  CREATOR_KIND_ENUM = {user: 0, organization: 1, pos: 2}

  belongs_to :bike_sticker
  belongs_to :bike
  belongs_to :user
  belongs_to :organization

  enum kind: KIND_ENUM
  enum creator_kind: CREATOR_KIND_ENUM
end
