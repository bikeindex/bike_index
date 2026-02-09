# == Schema Information
#
# Table name: normalized_serial_segments
# Database name: primary
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
#  index_normalized_serial_segments_on_segment                  (segment)
#
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
