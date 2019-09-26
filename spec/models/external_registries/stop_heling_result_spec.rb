require "rails_helper"

module ExternalRegistries
  RSpec.describe ExternalRegistries::StopHelingResult, type: :model do
    before(:all) do
      ::ExternalRegistry.create_all
    end

    after(:all) do
      ::ExternalRegistry.destroy_all
    end

    let(:response_object) do
      {}.tap do |h|
        h[:brand] = "Huffy"
        h[:brand_type] = "Beach Cruiser"
        h[:category] = "Cool Bike"
        h[:color] = "blue"
        h[:object] = "fiets"
        h[:insert_date] = "2018-02-24"
        h[:license_plate_number] = "4883833"
        h[:registration_number] = "12334"
        h[:source_name] = "HUPD"
        h[:source_unique_id] = "38382"
      end
    end

    describe "#to_external_registry_bike" do
      it "returns a validly constructed ExternalRegistryBike" do
        result = described_class.new(**response_object)
        bike = result.to_external_registry_bike
        expect(bike).to be_an_instance_of(ExternalRegistryBike)
        expect(bike.type).to eq("bike")
        expect(bike.status).to eq("Stolen")
        expect(bike.url).to eq("https://www.stopheling.nl")
        expect(bike.registry_name).to eq("stopheling.nl")
        expect(bike.mnfg_name).to eq(result.brand)
        expect(bike.frame_model).to eq(result.brand_type)
        expect(bike.date_stolen).to eq(result.date_found)
      end
    end
  end
end
