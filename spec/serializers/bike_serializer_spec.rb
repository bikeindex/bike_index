require "spec_helper"

describe BikeSerializer do
  describe "standard validations" do 
    let(:bike) { FactoryGirl.create(:bike, frame_size: '42') }
    let(:component) { FactoryGirl.create(:component, bike: bike)}
    let(:public_image) { FactoryGirl.create(:public_image, imageable_type: "Bike", imageable_id: bike.id)}
    subject { BikeSerializer.new(bike) }
    
    it { subject.manufacturer_name.should == bike.manufacturer_name }
    it { subject.manufacturer_id.should == bike.manufacturer_id }
    it { subject.stolen.should == bike.stolen }
    it { subject.type_of_cycle.should == bike.cycle_type.name }
    it { subject.name.should == bike.name }
    it { subject.year.should == bike.year }
    it { subject.frame_model.should == bike.frame_model }
    it { subject.description.should == bike.description }
    it { subject.rear_tire_narrow.should == bike.rear_tire_narrow }
    it { subject.front_tire_narrow.should == bike.front_tire_narrow }
    it { subject.rear_wheel_size.should == bike.rear_wheel_size }
    it { subject.serial.should == bike.serial_number }
    it { subject.front_wheel_size.should == bike.front_wheel_size }
    it { subject.handlebar_type.should == bike.handlebar_type }
    it { subject.frame_material.should == bike.frame_material }
    it { subject.front_gear_type.should == bike.front_gear_type }
    it { subject.rear_gear_type.should == bike.rear_gear_type }
    it { subject.stolen_record.should == bike.current_stolen_record }
    it { subject.frame_size.should == "42cm" }
    # it { subject.photo.should == bike.reload.public_images.first.image_url(:large) }
    # it { subject.thumb.should == bike.reload.public_images.first.image_url(:small) }
  end

end
