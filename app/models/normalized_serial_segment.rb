class NormalizedSerialSegment < ActiveRecord::Base
  belongs_to :bike
  validates_presence_of :bike_id
  validates_presence_of :segment
  belongs_to :duplicate_bike_group

  validates_uniqueness_of :segment, scope: [:bike_id]
end
