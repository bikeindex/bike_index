require "rails_helper"

RSpec.describe ExternalRegistryBike, type: :model do
  before do
    null_cache = ActiveSupport::Cache.lookup_store(:null_store)
    allow(Rails).to receive(:cache).and_return(null_cache)
  end

  after do
    allow(Rails).to receive(:cache).and_call_original
  end

  describe "#normalize_serial_number before_validation hooks" do
    it "normalizes the serial number" do
      bike1 = FactoryBot.create(:external_registry_bike, serial_number: "hello")
      expect(bike1.serial_normalized).to eq("HE110")

      bike2 = FactoryBot.create(:external_registry_bike, serial_number: "heIIO")
      expect(bike2.serial_normalized).to eq("HE110")
    end

    it "ensures a normalized serial number is present" do
      bike = FactoryBot.build(:external_registry_bike, serial_number: "unknown")
      bike.save
      expect(bike).to_not be_valid
      expect(bike).to_not be_persisted
      expect(bike.errors[:serial_normalized]).to include("can't be blank")
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

        allow(ExternalRegistryClient)
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
      it "returns partial matches found on external registries", :skip_db_cleaner do
        serial = "2722"
        _local_non_match = FactoryBot.build(:external_registry_bike)
        allow(ExternalRegistryClient).to receive(:search_for_bikes_with) do
          FactoryBot.create(:external_registry_bike, serial_number: "32722")
          ExternalRegistryBike.all
        end

        results = described_class.find_or_search_registry_for(serial_number: serial)

        expect(results.where(serial_number: serial).count).to eq(0)
        expect(results.count).to eq(1)
      end
    end
  end
end
