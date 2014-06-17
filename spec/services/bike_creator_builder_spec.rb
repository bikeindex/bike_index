require 'spec_helper'

describe BikeCreatorBuilder do

  describe :new_bike do 
    it "should return a new bike object from the params with the b_param_id" do
      bike = Bike.new
      b_param = BParam.new 
      b_param.stub(:id).and_return(9)
      b_param.stub(:params).and_return(bike: {serial_number: "AAAA"})
      bike = BikeCreatorBuilder.new(b_param).new_bike
      bike.serial_number.should eq("AAAA")
      bike.b_param_id.should eq(9)
    end
  end

  describe :add_front_wheel_size do
    it "should set the front wheel equal to the rear wheel if it's present" do 
      cycle_type = FactoryGirl.create(:cycle_type, name: "Bike", slug: "bike")
      bike = Bike.new
      b_param = BParam.new 
      bike.stub(:cycle_type_id).and_return(cycle_type.id)
      bike.stub(:rear_wheel_size_id).and_return(1)
      bike.stub(:rear_tire_narrow).and_return(true)
      BikeCreatorBuilder.new(b_param).add_front_wheel_size(bike)
      bike.front_wheel_size_id.should eq(1)
      bike.rear_tire_narrow.should be_true
    end
  end

  describe :add_required_attributes do 
    it "should call the methods it needs to call" do 
      cycle_type = FactoryGirl.create(:cycle_type, name: "Bike", slug: "bike")
      propulsion_type = FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      bike = Bike.new
      b_param = BParam.new
      creator = BikeCreatorBuilder.new(b_param)
      creator.add_required_attributes(bike)
      bike.cycle_type.should eq(cycle_type)
      bike.propulsion_type.should eq(propulsion_type)
    end
  end

  describe :verified_bike do
    it "should call bike_creator_verifier the required attributes" do 
      b_param = BParam.new
      bike = Bike.new
      BikeCreatorVerifier.any_instance.should_receive(:verify).and_return(bike)
      BikeCreatorBuilder.new(b_param).verified_bike(bike).should eq(bike)
    end
  end

  describe :build_new do 
    it "should call verified bike on new bike and return the bike" do 
      bike = Bike.new 
      creator = BikeCreatorBuilder.new()
      creator.should_receive(:new_bike).and_return(bike)
      creator.should_receive(:verified_bike).and_return(bike)
      creator.stub(:add_required_attributes).and_return(bike)
      creator.build_new.should eq(bike)
    end
  end

  describe :build do 
    it "should return the b_param bike if one exists" do 
      b_param = BParam.new
      bike = Bike.new 
      b_param.stub(:bike).and_return(bike)
      b_param.stub(:created_bike).and_return(bike)
      BikeCreatorBuilder.new(b_param).build.should eq(bike)
    end
    
    it "should use build_new and call other things" do 
      b_param = BParam.new
      bike = Bike.new 
      b_param.stub(:created_bike).and_return(nil)
      creator = BikeCreatorBuilder.new(b_param)
      creator.stub(:build_new).and_return(bike)
      creator.should_receive(:add_front_wheel_size).and_return(true)
      creator.build.should eq(bike)
    end
  end

end