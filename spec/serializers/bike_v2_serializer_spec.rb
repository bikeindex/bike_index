require "rails_helper"

RSpec.describe BikeV2Serializer do
  let(:serializer) { BikeV2Serializer.new(bike) }
  describe "standard validations" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership, year: 2011) }
    let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }

    let(:target) do
      {
        id: bike.id,
        title: bike.title_string,
        serial: bike.serial_number,
        manufacturer_name: bike.mnfg_name,
        frame_model: nil,
        year: 2011,
        frame_colors: ["Black"],
        thumb: public_image.image_url(:small),
        large_img: public_image.image_url(:large),
        is_stock_img: false,
        stolen: false,
        stolen_location: nil,
        stolen_coordinates: nil,
        date_stolen: nil,
        url: "http://test.host/bikes/#{bike.id}",
        registry_url: nil,
        registry_name: nil,
        location_found: nil,
        description: nil,
        external_id: nil,
        status: "with owner"
      }
    end

    it "returns the expected thing" do
      expect(bike.reload.status).to eq "status_with_owner"
      expect(serializer.as_json(root: false)).to eq target
    end

    context "stolen bike" do
      let(:bike) { FactoryBot.create(:stolen_bike_in_nyc, :with_ownership) }
      let(:target_stolen) do
        target.merge(year: nil,
          status: "stolen",
          stolen_location: "New York, NY - US",
          stolen: true,
          stolen_coordinates: [40.71, -74.01], # public (truncated) coordinates
          date_stolen: bike.current_stolen_record.date_stolen.to_i)
      end
      it "returns the expected thing" do
        expect(bike.reload.status).to eq "status_stolen"
        expect(bike.address).to eq "278 Broadway, New York, NY 10007, US"
        expect(serializer.as_json(root: false)).to eq target_stolen
      end
    end
    context "found bike" do
      let!(:impound_record) { FactoryBot.create(:impound_record, :in_nyc, bike: bike) }
      let(:target_found) do
        target.merge(location_found: "278 Broadway, New York, NY 10007, US",
          status: "found",
          serial: "Hidden")
      end
      it "returns the expected thing" do
        expect(bike.reload.status).to eq "status_impounded"
        expect(impound_record.reload.address).to eq "New York, NY 10007"
        expect(impound_record.to_coordinates).to eq([40.7143528, -74.0059731])
        expect(bike.to_coordinates).to eq([40.7143528, -74.0059731])
        expect(serializer.as_json(root: false)).to eq target_found
      end
    end
  end

  describe "caching" do
    let(:bike) { Bike.new }
    include_context :caching_basic
    # TODO: after #2123, switch this to cache!
    it "is not cached" do
      expect(serializer.perform_caching).to be_falsey
      expect(serializer.as_json.is_a?(Hash)).to be_truthy
    end
  end
end
