require "rails_helper"

RSpec.describe DuplicateBikeGroup, type: :model do
  describe "factory" do
    let(:duplicate_bike_group) { FactoryBot.create(:duplicate_bike_group) }
    it "is valid" do
      expect(duplicate_bike_group.valid?).to be_truthy
      expect(duplicate_bike_group.normalized_serial_segments.count).to eq 2
      expect(duplicate_bike_group.bikes.count).to eq 2
      expect(duplicate_bike_group.bikes.first.duplicate_bikes.count).to eq 2
      duplicate_bike_group.update(ignore: true)
      # If ignored, bikes ignore
      expect(duplicate_bike_group.bikes.first.duplicate_bikes.count).to eq 0
    end
  end

  describe "segment" do
    it "returns the first segment" do
      duplicate_bike_group = DuplicateBikeGroup.new
      normalized_serial_segment = NormalizedSerialSegment.new(segment: "stuff")
      allow(duplicate_bike_group).to receive(:normalized_serial_segments).and_return([normalized_serial_segment])
      expect(duplicate_bike_group.segment).to eq("stuff")
    end
  end
end
