require "rails_helper"

RSpec.describe MigrateNormalizedSerialSegmentsWorker, type: :job do
  let(:instance) { described_class.new }

  it "adds the missing serial segments" do
    bike = FactoryBot.create(:bike, serial_number: "applejacks cereal cross")
    bike.create_normalized_serial_segments
    expect(bike.reload.normalized_serial_segments.count).to eq 4
    expect(bike.normalized_serial_segments.last.segment).to eq "APP1EJACK5CEREA1CR055"
    bike.normalized_serial_segments.last.destroy
    og_segment_ids = bike.normalized_serial_segments.pluck(:id)
    instance.perform(bike.id)
    expect(bike.reload.normalized_serial_segments.count).to eq 4
    # Verify that it isn't deleting
    expect((bike.normalized_serial_segments.pluck(:id) & og_segment_ids).count).to eq 3
    expect(bike.serial_segments_migrated_at).to be_present
  end

  context "user_hidden" do
    let!(:bike) { FactoryBot.create(:bike, serial_number: "Y0AASF FFFF", user_hidden: true) }
    it "creates for user_hidden" do
      instance.perform(bike.id)
      expect(bike.reload.normalized_serial_segments.count).to eq 3
    end
  end

  context "example" do
    let!(:bike) { FactoryBot.create(:bike, serial_number: "Y0AAS FFFFF") }
    it "deletes" do
      bike.create_normalized_serial_segments
      bike.update(example: true)
      expect(bike.reload.normalized_serial_segments.count).to eq 3
      instance.perform(bike.id)
      expect(bike.reload.normalized_serial_segments.count).to eq 0
      expect(bike.serial_segments_migrated_at).to be_present
    end
  end
end
