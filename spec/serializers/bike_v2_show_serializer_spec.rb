require "rails_helper"

RSpec.describe BikeV2ShowSerializer do
  describe "standard validations" do
    let(:bike) { FactoryBot.create(:bike, frame_size: "42", additional_registration: "XXYY") }
    let!(:component) { FactoryBot.create(:component, bike: bike) }
    let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
    subject { BikeV2ShowSerializer.new(bike) }

    let(:public_image_target) do
      {
        name: public_image.name,
        full: public_image.image_url,
        large: public_image.image_url(:large),
        medium: public_image.image_url(:medium),
        thumb: public_image.image_url(:small),
        id: public_image.id,
      }
    end
    let(:component_target) do
      {
        id: component.id,
        description: component.description,
        serial_number: component.serial_number,
        component_type: component.component_type,
        component_group: component.component_group,
        rear: component.rear,
        front: component.front,
        manufacturer_name: component.manufacturer_name,
        model_name: component.cmodel_name,
        year: component.year,
      }
    end

    let(:target) do
      {
        id: bike.id,
        title: bike.title_string,
        serial: bike.serial_number,
        manufacturer_name: bike.mnfg_name,
        frame_model: nil,
        year: nil,
        frame_colors: ["Black"],
        thumb: public_image.image_url(:small),
        large_img: public_image.image_url(:large),
        is_stock_img: false,
        stolen: false,
        stolen_location: nil,
        date_stolen: nil,
        date_stolen_string: nil,
        registration_created_at: bike.created_at.to_i,
        registration_updated_at: bike.updated_at.to_i,
        url: "http://test.host/bikes/#{bike.id}",
        api_url: "http://test.host/api/v1/bikes/#{bike.id}",
        manufacturer_id: bike.manufacturer_id,
        paint_description: nil,
        placeholder_image: "http://test.host/assets/revised/bike_photo_placeholder-ff15adbd9bf89e10bf3cd2cd6c4e85e5d1056e50463ae722822493624db72e56.svg",
        name: nil,
        frame_size: "42cm",
        description: nil,
        rear_tire_narrow: true,
        front_tire_narrow: nil,
        type_of_cycle: "Bike",
        test_bike: false,
        frame_material_slug: nil,
        rear_wheel_size_iso_bsd: nil,
        front_wheel_size_iso_bsd: nil,
        handlebar_type_slug: nil,
        front_gear_type_slug: nil,
        rear_gear_type_slug: nil,
        additional_registration: "XXYY",
        stolen_record: nil,
        public_images: [public_image_target],
        components: [component_target],
        debug: nil,
        location_found: nil,
        registry_id: nil,
        registry_name: nil,
        registry_url: nil,
        source_name: nil,
        source_unique_id: nil,
        status: nil,
      }
    end

    it "returns the expected thing" do
      bike.reload
      expect(subject.as_json(root: false)).to eq target
    end
  end
end
