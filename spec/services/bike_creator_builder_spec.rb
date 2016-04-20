require 'spec_helper'

describe BikeCreatorBuilder do
  describe 'new_bike' do
    it "returns a new bike object from the params with the b_param_id" do
      bike = Bike.new
      b_param = BParam.new 
      allow(b_param).to receive(:id).and_return(9)
      allow(b_param).to receive(:creator_id).and_return(6)
      allow(b_param).to receive(:params).and_return(bike: {serial_number: "AAAA"})
      bike = BikeCreatorBuilder.new(b_param).new_bike
      expect(bike.serial_number).to eq("AAAA")
      expect(bike.updator_id).to eq(6)
      expect(bike.b_param_id).to eq(9)
    end
  end

  describe 'add_front_wheel_size' do
    it "sets the front wheel equal to the rear wheel if it's present" do
      cycle_type = FactoryGirl.create(:cycle_type, name: "Bike", slug: "bike")
      bike = Bike.new
      b_param = BParam.new 
      allow(bike).to receive(:cycle_type_id).and_return(cycle_type.id)
      allow(bike).to receive(:rear_wheel_size_id).and_return(1)
      allow(bike).to receive(:rear_tire_narrow).and_return(true)
      BikeCreatorBuilder.new(b_param).add_front_wheel_size(bike)
      expect(bike.front_wheel_size_id).to eq(1)
      expect(bike.rear_tire_narrow).to be_truthy
    end
  end

  describe 'add_required_attributes' do
    it "calls the methods it needs to call" do
      cycle_type = FactoryGirl.create(:cycle_type, name: "Bike", slug: "bike")
      propulsion_type = FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      bike = Bike.new
      b_param = BParam.new
      creator = BikeCreatorBuilder.new(b_param)
      creator.add_required_attributes(bike)
      expect(bike.cycle_type).to eq(cycle_type)
      expect(bike.propulsion_type).to eq(propulsion_type)
    end
  end

  describe 'verified_bike' do
    it "calls bike_creator_verifier the required attributes" do
      b_param = BParam.new
      bike = Bike.new
      expect_any_instance_of(BikeCreatorVerifier).to receive(:verify).and_return(bike)
      expect(BikeCreatorBuilder.new(b_param).verified_bike(bike)).to eq(bike)
    end
  end

  describe 'build_new' do
    it "calls verified bike on new bike and return the bike" do
      bike = Bike.new 
      creator = BikeCreatorBuilder.new()
      expect(creator).to receive(:new_bike).and_return(bike)
      expect(creator).to receive(:verified_bike).and_return(bike)
      allow(creator).to receive(:add_required_attributes).and_return(bike)
      expect(creator.build_new).to eq(bike)
    end
  end

  describe 'build' do
    it "returns the b_param bike if one exists" do
      b_param = BParam.new
      bike = Bike.new 
      allow(b_param).to receive(:bike).and_return(bike)
      allow(b_param).to receive(:created_bike).and_return(bike)
      expect(BikeCreatorBuilder.new(b_param).build).to eq(bike)
    end
    
    it "uses build_new and call other things" do
      b_param = BParam.new
      bike = Bike.new 
      allow(b_param).to receive(:created_bike).and_return(nil)
      creator = BikeCreatorBuilder.new(b_param)
      allow(creator).to receive(:build_new).and_return(bike)
      expect(creator).to receive(:add_front_wheel_size).and_return(true)
      expect(creator.build).to eq(bike)
    end
  end

end
