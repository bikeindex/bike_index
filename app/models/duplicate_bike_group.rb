class DuplicateBikeGroup < ActiveRecord::Base
  has_many :normalized_serial_segments
  has_many :bikes, through: :normalized_serial_segments
  attr_accessible :added_bike_at, :ignore

  scope :unignored, where(ignore: false)
  
  before_save :update_added_bike_at
  def update_added_bike_at
    self.added_bike_at ||= Time.now
  end

  def segment
    normalized_serial_segments && normalized_serial_segments.first &&
      normalized_serial_segments.first.segment || ''
  end
end
