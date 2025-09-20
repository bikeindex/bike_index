# == Schema Information
#
# Table name: normalized_serial_segments
#
#  id                      :integer          not null, primary key
#  segment                 :string(255)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  bike_id                 :integer
#  duplicate_bike_group_id :integer
#
# Indexes
#
#  index_normalized_serial_segments_on_bike_id                  (bike_id)
#  index_normalized_serial_segments_on_duplicate_bike_group_id  (duplicate_bike_group_id)
#
class NormalizedSerialSegment < ApplicationRecord
  MINIMUM_LENGTH_FOR_DUPLICATE_GROUP = 5
  belongs_to :bike
  validates :bike_id, presence: true
  validates :segment, presence: true
  belongs_to :duplicate_bike_group

  validates :segment, uniqueness: {scope: [:bike_id]}

  scope :duplicate_bike_group, -> { where.not(duplicate_bike_group_id: nil) }
  scope :considered_for_duplicate, -> { where("length(segment) > ?", MINIMUM_LENGTH_FOR_DUPLICATE_GROUP) }
end
