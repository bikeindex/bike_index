require "rails_helper"

RSpec.describe SearchForExternalRegistryBikesWorker, type: :job do
  before { ExternalRegistryBike.delete_all }

  describe "#perform" do
    context "given no matching bikes returned" do
      it "does not persist records to external_registry_bikes" do
        expect(ExternalRegistryBike.count).to eq(0)
        VCR.use_cassette("external_registry/verlorenofgevonden_13949483_no_results") do
          described_class.new.perform(13949483)
        end
        expect(ExternalRegistryBike.count).to eq(0)
      end
    end

    context "given matching bike returned" do
      it "persists any matches found to external_registry_bikes" do
        expect(ExternalRegistryBike.count).to eq(0)

        VCR.use_cassette("external_registry/all_registries_2722_with_results") do
          described_class.new.perform(2722)
        end

        expect(ExternalRegistryBike.count).to eq(5)
        serial_or_id_match =
          ExternalRegistryBike
            .all
            .map { |bike| [bike.serial_number, bike.external_id] }
            .map { |ids| ids.any? { |id| /2722/.match(id) } }

        expect(serial_or_id_match).to all(eq(true))
      end
    end
  end
end
