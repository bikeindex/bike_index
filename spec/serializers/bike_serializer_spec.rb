require "spec_helper"

describe BikeSerializer, type: :lib  do
  describe "standard validations" do
    let(:bike) { FactoryGirl.create(:bike, frame_size: '42') }
    let(:component) { FactoryGirl.create(:component, bike: bike) }
    let(:public_image) { FactoryGirl.create(:public_image, imageable_type: 'Bike', imageable_id: bike.id) }
    let(:serializer) { BikeSerializer.new(bike) }

    it "is as expected" do
      expect(serializer.manufacturer_name).to eq(bike.mnfg_name)
      expect(serializer.manufacturer_id).to eq(bike.manufacturer_id)
      expect(serializer.stolen).to eq(bike.stolen)
      expect(serializer.type_of_cycle).to eq(bike.cycle_type.name)
      expect(serializer.name).to eq(bike.name)
      expect(serializer.year).to eq(bike.year)
      expect(serializer.frame_model).to eq(bike.frame_model)
      expect(serializer.description).to eq(bike.description)
      expect(serializer.rear_tire_narrow).to eq(bike.rear_tire_narrow)
      expect(serializer.front_tire_narrow).to eq(bike.front_tire_narrow)
      expect(serializer.rear_wheel_size).to eq(bike.rear_wheel_size)
      expect(serializer.serial).to eq(bike.serial_number)
      expect(serializer.front_wheel_size).to eq(bike.front_wheel_size)
      expect(serializer.handlebar_type).to eq(bike.handlebar_type)
      expect(serializer.frame_material).to eq(bike.frame_material)
      expect(serializer.front_gear_type).to eq(bike.front_gear_type)
      expect(serializer.rear_gear_type).to eq(bike.rear_gear_type)
      expect(serializer.stolen_record).to eq(bike.current_stolen_record)
      expect(serializer.frame_size).to eq('42cm')
      # expect(serializer.photo).to == bike.reload.public_images.first.image_url(:large)
      # expect(serializer.thumb).to == bike.reload.public_images.first.image_url(:small)
    end
    describe "caching" do
      include_context :caching_basic
      it "is not cached" do
        expect(serializer.perform_caching).to be_falsey
        expect(serializer.as_json.is_a?(Hash)).to be_truthy
      end
    end
  end
end
