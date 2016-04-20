require 'spec_helper'

describe DuplicateBikeGroup do
  it { is_expected.to have_many :normalized_serial_segments }
  it { is_expected.to have_many :bikes }

  describe 'segment' do
    it "returns the first segment" do
      duplicate_bike_group = DuplicateBikeGroup.new 
      normalized_serial_segment = NormalizedSerialSegment.new(segment: 'stuff')
      allow(duplicate_bike_group).to receive(:normalized_serial_segments).and_return([normalized_serial_segment])
      expect(duplicate_bike_group.segment).to eq('stuff')
    end
  end  
end
