# == Schema Information
#
# Table name: duplicate_bike_groups
#
#  id            :integer          not null, primary key
#  added_bike_at :datetime
#  ignore        :boolean          default(FALSE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
class DuplicateBikeGroup < ApplicationRecord
  has_many :normalized_serial_segments
  has_many :bikes, through: :normalized_serial_segments

  scope :unignored, -> { where(ignore: false) }

  before_save :update_added_bike_at

  def self.matching_segment(segment)
    includes(:normalized_serial_segments)
      .where(normalized_serial_segments: {segment: segment}).first
  end

  def update_added_bike_at
    self.added_bike_at ||= Time.current
  end

  def segment
    normalized_serial_segments&.first&.segment || ""
  end
end
