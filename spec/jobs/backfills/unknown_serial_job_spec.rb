require "rails_helper"

RSpec.describe Backfills::UnknownSerialJob, type: :job do
  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let!(:placeholder_bikes) { 2.times.map { FactoryBot.create(:bike, manufacturer:) } }
  let!(:serial_bikes) { 2.times.map { FactoryBot.create(:bike, manufacturer:, serial_number: "WTU123456") } }

  it "stores placeholder serials as unknown and releases their duplicate group" do
    # Registered before SerialNormalizer treated the placeholder as unknown
    placeholder_bikes.each do |bike|
      bike.update_columns(serial_number: "Not-Assigned", serial_normalized: "N0T A55IGNED", serial_normalized_no_space: "N0TA55IGNED")
      %w[N0T A55IGNED N0TA55IGNED].each { NormalizedSerialSegment.create!(bike:, segment: it) }
    end
    serial_bikes.each(&:create_normalized_serial_segments)
    (placeholder_bikes + serial_bikes).each { BikeJobs::DuplicateBikeFinderJob.new.perform(it.id) }
    expect(DuplicateBikeGroup.count).to eq 3 # A55IGNED, N0TA55IGNED and WTU123456

    described_class.new.perform
    placeholder_bikes.each do |bike|
      expect(bike.reload).to have_attributes(serial_number: "unknown", serial_normalized: nil, serial_normalized_no_space: nil)
      expect(NormalizedSerialSegment.where(bike_id: bike.id)).to be_empty
    end
    expect(serial_bikes.map { it.reload.serial_number }).to eq %w[WTU123456 WTU123456]
    expect(DuplicateBikeGroup.count).to eq 1
    expect(DuplicateBikeGroup.first.bikes).to match_array serial_bikes
  end
end
