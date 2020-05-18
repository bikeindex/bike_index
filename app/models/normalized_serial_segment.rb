class NormalizedSerialSegment < ApplicationRecord
  MINIMUM_LENGTH_FOR_DUPLICATE_GROUP = 5
  belongs_to :bike
  validates_presence_of :bike_id
  validates_presence_of :segment
  belongs_to :duplicate_bike_group

  validates_uniqueness_of :segment, scope: [:bike_id]

  scope :duplicate_bike_group, -> { where.not(duplicate_bike_group_id: nil) }
  scope :considered_for_duplicate, -> { where("length(segment) > ?", MINIMUM_LENGTH_FOR_DUPLICATE_GROUP) }
end
