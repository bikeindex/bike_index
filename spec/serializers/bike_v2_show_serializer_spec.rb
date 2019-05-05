require "spec_helper"

describe BikeV2ShowSerializer do
  describe "standard validations" do
    let(:bike) { FactoryBot.create(:bike, frame_size: "42", additional_registration: "XXYY") }
    let(:component) { FactoryBot.create(:component, bike: bike) }
    let(:public_image) { FactoryBot.create(:public_image, imageable_type: "Bike", imageable_id: bike.id) }
    subject { BikeV2ShowSerializer.new(bike) }

    let(:target) do
      {
        id: bike.id,
        title: bike.title_string,
        serial: bike.serial_number,
        manufacturer_name: bike.mnfg_name,
        frame_model: nil,
        year: nil,
        frame_colors: ["Black"],
        thumb: nil,
        large_img: nil,
        is_stock_img: false,
        stolen: false,
        stolen_location: nil,
        date_stolen: nil,
        frame_material: nil,
        handlebar_type: nil,
        registration_created_at: bike.created_at.to_i,
        registration_updated_at: bike.updated_at.to_i,
        url: "http://test.host/bikes/#{bike.id}",
        api_url: "http://test.host/api/v1/bikes/#{bike.id}",
        manufacturer_id: bike.manufacturer_id,
        paint_description: nil,
        name: nil,
        frame_size: "42cm",
        description: nil,
        rear_tire_narrow: true,
        front_tire_narrow: nil,
        type_of_cycle: "Bike",
        test_bike: false,
        rear_wheel_size_iso_bsd: nil,
        front_wheel_size_iso_bsd: nil,
        handlebar_type_slug: nil,
        front_gear_type_slug: nil,
        rear_gear_type_slug: nil,
        additional_registration: "XXYY",
        stolen_record: nil,
        public_images: [],
        components: [],
      }
    end

    it "returns the expected thing" do
      expect(subject.as_json(root: false)).to eq target
    end
  end
end
