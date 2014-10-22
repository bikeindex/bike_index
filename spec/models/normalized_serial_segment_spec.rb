require 'spec_helper'

describe NormalizedSerialSegment do
  it { should belong_to :bike }
  it { should validate_presence_of :bike_id }
  it { should validate_presence_of :segment }
  it { should validate_uniqueness_of(:segment).scoped_to(:bike_id) }
end
