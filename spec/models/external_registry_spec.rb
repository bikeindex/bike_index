require "rails_helper"

RSpec.describe ExternalRegistry, type: :model do
  before(:all) do
    ::ExternalRegistry.create_all
  end

  after(:all) do
    ::ExternalRegistry.destroy_all
  end

  describe ".search_for_bikes_with" do
    context "when matches are found" do
      it "returns an ActiveRecord relation of ExternalRegistryBikes" do
        VCR.use_cassette("external_registries/all_registries_2722_with_results") do
          serial_number = 2722
          results = described_class.search_for_bikes_with(serial_number: serial_number)
          expect(results).to be_an(ActiveRecord::Relation)
          expect(results).to all(be_an(ExternalRegistryBike))
          expect(results).to_not be_empty
        end
      end
    end

    context "when no matches are found" do
      it "returns an empty ActiveRecord relation" do
        VCR.use_cassette("external_registries/all_registries_13949483_no_results") do
          serial_number = 13949483
          results = described_class.search_for_bikes_with(serial_number: serial_number)
          expect(results).to be_an(ActiveRecord::Relation)
          expect(results).to be_empty
        end
      end
    end
  end
end
