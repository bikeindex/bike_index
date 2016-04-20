require 'spec_helper'

describe NormalizedSerialSegment do
  it { is_expected.to belong_to :bike }
  it { is_expected.to belong_to :duplicate_bike_group }
  it { is_expected.to validate_presence_of :bike_id }
  it { is_expected.to validate_presence_of :segment }
  it { is_expected.to validate_uniqueness_of(:segment).scoped_to(:bike_id) }
end
