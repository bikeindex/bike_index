require "rails_helper"

RSpec.describe ExternalRegistryBike, type: :model do
  before do
    ExternalRegistryBike.delete_all
    null_cache = ActiveSupport::Cache.lookup_store(:null_store)
    allow(Rails).to receive(:cache).and_return(null_cache)
  end

  after do
    allow(Rails).to receive(:cache).and_call_original
  end

  around(:each) do |example|
    VCR.use_cassette("external_registry/all_registries_2722_with_results") do
      example.run
    end
  end

  describe "#normalize_serial_number before_save hooks" do
    it "normalizes the serial number" do
      bike1 = FactoryBot.build(:external_registry_bike, serial_number: "hello")
      bike1.save
      expect(bike1.serial_normalized).to eq("HE110")

      bike2 = FactoryBot.build(:external_registry_bike, serial_number: "heIIO")
      bike2.save
      expect(bike2.serial_normalized).to eq("HE110")
    end
  end

  describe ".find_or_search_registry_for" do
    context "given a locally found exact match" do
      it "returns only the exact match" do
        bike = FactoryBot.create(:external_registry_bike)
        results = described_class.find_or_search_registry_for(serial_number: bike.serial_number)
        expect(results).to eq([bike])
      end
    end

    context "given no locally found exact match" do
      it "searches external registries and returns remotely found exact matches" do
        exact_match_serial = "5127227"
        _local_non_match = FactoryBot.create(:external_registry_bike)

        allow(ExternalRegistry::ExternalRegistry)
          .to(receive(:search_for_bikes_with)
            .with(exact_match_serial) {
            FactoryBot.create(:external_registry_bike, serial_number: exact_match_serial)
            ExternalRegistryBike.where(serial_normalized: exact_match_serial)
          })

        results = described_class.find_or_search_registry_for(serial_number: exact_match_serial)

        expect(results.length).to eq(1)
        expect(results.pluck(:serial_number)).to eq([exact_match_serial])
      end
    end

    context "given no exact matches locally or remotely" do
      it "returns partial matches found on external registries" do
        serial = "2722"
        _local_non_match = FactoryBot.build(:external_registry_bike)
        results = described_class.find_or_search_registry_for(serial_number: serial)
        expect(results.where(serial_number: serial).count).to eq(0)
        expect(results.count).to eq(5)
      end
    end
  end
end
