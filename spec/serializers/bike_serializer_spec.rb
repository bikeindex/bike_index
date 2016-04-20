require "spec_helper"

describe BikeSerializer do
  describe "standard validations" do
    let(:bike) { FactoryGirl.create(:bike, frame_size: '42') }
    let(:component) { FactoryGirl.create(:component, bike: bike)}
    let(:public_image) { FactoryGirl.create(:public_image, imageable_type: "Bike", imageable_id: bike.id)}
    subject { BikeSerializer.new(bike) }
    
    it { expect(subject.manufacturer_name).to eq(bike.manufacturer_name) }
    it { expect(subject.manufacturer_id).to eq(bike.manufacturer_id) }
    it { expect(subject.stolen).to eq(bike.stolen) }
    it { expect(subject.type_of_cycle).to eq(bike.cycle_type.name) }
    it { expect(subject.name).to eq(bike.name) }
    it { expect(subject.year).to eq(bike.year) }
    it { expect(subject.frame_model).to eq(bike.frame_model) }
    it { expect(subject.description).to eq(bike.description) }
    it { expect(subject.rear_tire_narrow).to eq(bike.rear_tire_narrow) }
    it { expect(subject.front_tire_narrow).to eq(bike.front_tire_narrow) }
    it { expect(subject.rear_wheel_size).to eq(bike.rear_wheel_size) }
    it { expect(subject.serial).to eq(bike.serial_number) }
    it { expect(subject.front_wheel_size).to eq(bike.front_wheel_size) }
    it { expect(subject.handlebar_type).to eq(bike.handlebar_type) }
    it { expect(subject.frame_material).to eq(bike.frame_material) }
    it { expect(subject.front_gear_type).to eq(bike.front_gear_type) }
    it { expect(subject.rear_gear_type).to eq(bike.rear_gear_type) }
    it { expect(subject.stolen_record).to eq(bike.current_stolen_record) }
    it { expect(subject.frame_size).to eq("42cm") }
    # it { subject.photo.should == bike.reload.public_images.first.image_url(:large) }
    # it { subject.thumb.should == bike.reload.public_images.first.image_url(:small) }
  end

end
