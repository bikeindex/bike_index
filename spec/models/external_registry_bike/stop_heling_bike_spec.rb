require "rails_helper"

RSpec.describe ExternalRegistryBike::StopHelingBike, type: :model do
  let(:api_response) do
    {
      brand: "Huffy",
      brand_type: "Beach Cruiser",
      category: "Cool Bike",
      color: "blue",
      object: "fiets",
      insert_date: "2018-02-24",
      license_plate_number: "4883833",
      registration_number: "12334",
      source_name: "HUPD",
      source_unique_id: "38382"
    }
  end

  describe "#build_from_api_response" do
    context "given a response object for a bike" do
      it "returns a validly constructed ExternalRegistryBike" do
        bike = described_class.build_from_api_response(api_response)

        expect(bike).to be_a(ExternalRegistryBike)
        expect(bike).to be_an_instance_of(ExternalRegistryBike::StopHelingBike)
        expect(bike.cycle_type).to eq("bike")
        expect(bike.status).to eq("stolen")
        expect(bike.url).to eq("https://www.stopheling.nl")
        expect(bike.registry_name).to eq("stopheling.nl")
        expect(bike.mnfg_name).to eq(api_response[:brand])
        expect(bike.frame_model).to eq(api_response[:brand_type])
        expect(bike.date_stolen).to eq(api_response[:insert_date])
        expect(bike).to_not be_persisted
        expect(bike).to be_valid
      end
    end

    context "given a non-bike response object" do
      it "returns nil" do
        non_bike = {object: "PERSONENAUTO"}
        bike = described_class.build_from_api_response(non_bike)
        expect(bike).to eq(nil)
      end
    end
  end
end
