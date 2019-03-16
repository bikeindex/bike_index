require 'spec_helper'

describe BikeV2ShowSerializer do
  describe 'standard validations' do
    let(:bike) { FactoryBot.create(:bike, frame_size: '42') }
    let(:component) { FactoryBot.create(:component, bike: bike) }
    let(:public_image) { FactoryBot.create(:public_image, imageable_type: 'Bike', imageable_id: bike.id) }
    subject { BikeV2ShowSerializer.new(bike) }

    it { expect(subject.manufacturer_name).to eq(bike.mnfg_name) }
    it { expect(subject.manufacturer_id).to eq(bike.manufacturer_id) }
    it { expect(subject.stolen).to eq(bike.stolen) }
    it { expect(subject.type_of_cycle).to eq(bike.cycle_type_name) }
    it { expect(subject.name).to eq(bike.name) }
    it { expect(subject.year).to eq(bike.year) }
    it { expect(subject.frame_model).to eq(bike.frame_model) }
    it { expect(subject.description).to eq(bike.description) }
    it { expect(subject.rear_tire_narrow).to eq(bike.rear_tire_narrow) }
    it { expect(subject.front_tire_narrow).to eq(bike.front_tire_narrow) }
    it { expect(subject.rear_tire_narrow).to eq(bike.rear_tire_narrow) }
    it { expect(subject.serial).to eq(bike.serial_number) }
    it { expect(subject.handlebar_type).to eq(bike.handlebar_type) }
    it { expect(subject.frame_material).to eq(bike.frame_material_name) }
    it { expect(subject.front_gear_type_slug).to eq(bike.front_gear_type_id) }
    it { expect(subject.rear_gear_type_slug).to eq(bike.rear_gear_type_id) }
    it { expect(subject.stolen_record).to eq(bike.current_stolen_record) }
    it { expect(subject.frame_size).to eq('42cm') }
    it { expect(subject.additional_registration).to eq(bike.additional_registration) }
    # it { subject.photo.should == bike.reload.public_images.first.image_url(:large) }
    # it { subject.thumb.should == bike.reload.public_images.first.image_url(:small) }
  end
end
