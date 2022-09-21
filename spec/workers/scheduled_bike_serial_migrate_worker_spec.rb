require "rails_helper"

RSpec.describe ScheduledBikeSerialMigrateWorker, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  describe "perform" do
    let(:serial) { "Some-Serial.  .Stuf?f" }
    let(:time) { Time.current - 1.week }
    let!(:bike) { FactoryBot.create(:bike, serial_number: serial, updated_at: time) }
    it "updates the serial number" do
      og_updated_at = bike.updated_at
      bike.update_columns(serial_number: serial, serial_normalized_no_space: nil)
      expect(bike.reload.serial_normalized_no_space).to be_blank
      expect(bike.serial_number).to eq serial
      expect(bike.updated_at).to be_within(1).of time
      expect(instance.potential_bikes.pluck(:id)).to eq([bike.id])
      instance.perform(bike.id)
      expect(bike.reload.serial_normalized_no_space).to eq "50ME5ER1A15TUFF"
      expect(bike.serial_number).to eq serial.gsub("  ", " ")
      expect(bike.updated_at).to be_within(1).of time
      expect(instance.potential_bikes.pluck(:id)).to eq([])
    end
    context "deleted bike" do
      it "still updates" do
        bike_id = bike.id
        bike.destroy
        expect(Bike.pluck(:id)).to eq([])
        bike = Bike.unscoped.find(bike_id)
        bike.update_columns(serial_number: serial, serial_normalized_no_space: nil, updated_at: time)
        expect(bike.serial_normalized_no_space).to be_blank
        expect(bike.serial_number).to eq serial
        expect(instance.potential_bikes.pluck(:id)).to eq([bike.id])
        instance.perform(bike.id)
        expect(bike.reload.serial_normalized_no_space).to eq "50ME5ER1A15TUFF"
        expect(bike.serial_number).to eq serial.gsub("  ", " ")
        expect(bike.updated_at).to be_within(1).of time
        expect(instance.potential_bikes.pluck(:id)).to eq([])
        expect(bike.deleted?).to be_truthy
      end
    end
  end
end
