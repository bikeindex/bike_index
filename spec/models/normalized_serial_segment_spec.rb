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
require "rails_helper"

RSpec.describe NormalizedSerialSegment, type: :model do
end
