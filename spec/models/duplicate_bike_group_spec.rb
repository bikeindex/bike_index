require 'spec_helper'

describe DuplicateBikeGroup do
  it { should have_many :normalized_serial_segments }
  it { should have_many :bikes }

  describe :segment do 
    it "returns the first segment" do 
      duplicate_bike_group = DuplicateBikeGroup.new 
      normalized_serial_segment = NormalizedSerialSegment.new(segment: 'stuff')
      duplicate_bike_group.stub(:normalized_serial_segments).and_return([normalized_serial_segment])
      expect(duplicate_bike_group.segment).to eq('stuff')
    end
  end  
end
