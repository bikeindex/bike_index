require "spec_helper"

describe BikeSerializer do
  let(:bike) { FactoryGirl.create(:bike) }
  let(:component) { FactoryGirl.create(:component, bike: bike)}
  let(:public_image) { FactoryGirl.create(:public_image, imageable_type: "Bike", imageable_id: bike.id)}
  subject { BikeSerializer.new(bike) }
  
  it { subject.manufacturer_name.should == bike.manufacturer_name }
  it { subject.manufacturer_id.should == bike.manufacturer_id }
  it { subject.stolen.should == bike.stolen }
  it { subject.name.should == bike.name }
  it { subject.frame_manufacture_year.should == bike.frame_manufacture_year }
  it { subject.frame_model.should == bike.frame_model }
  it { subject.seat_tube_length.should == bike.seat_tube_length }
  it { subject.seat_tube_length_in_cm.should == bike.seat_tube_length_in_cm }
  it { subject.description.should == bike.description }
  it { subject.rear_tire_narrow.should == bike.rear_tire_narrow }
  it { subject.front_tire_narrow.should == bike.front_tire_narrow }
  it { subject.rear_wheel_size.should == bike.rear_wheel_size }
  
  it { subject.front_wheel_size.should == bike.front_wheel_size }
  it { subject.primary_frame_color.should == bike.primary_frame_color }
  it { subject.secondary_frame_color.should == bike.secondary_frame_color }
  it { subject.tertiary_frame_color.should == bike.tertiary_frame_color }
  it { subject.handlebar_type.should == bike.handlebar_type }
  it { subject.frame_material.should == bike.frame_material }
  it { subject.front_gear_type.should == bike.front_gear_type }
  it { subject.rear_gear_type.should == bike.rear_gear_type }
  it { subject.current_stolen_record.should == bike.current_stolen_record }

end
