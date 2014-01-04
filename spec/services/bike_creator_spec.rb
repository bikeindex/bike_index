require 'spec_helper'

describe BikeCreator do

  describe :build_new_bike do 
    it "should call creator_builder" do 
      b_param = BParam.new
      BikeCreatorBuilder.any_instance.should_receive(:build_new).and_return(true)
      BikeCreator.new(b_param).build_new_bike
    end
  end

  describe :build_bike do 
    it "should call creator_builder" do 
      b_param = BParam.new
      BikeCreatorBuilder.any_instance.should_receive(:build).and_return(Bike.new)
      BikeCreator.new(b_param).build_bike.should be_true
    end
  end

  describe :create_associations do 
    it "should call creator_associator" do 
      b_param = BParam.new
      bike = Bike.new 
      b_param.stub(:bike).and_return(bike)
      BikeCreatorAssociator.any_instance.should_receive(:associate).and_return(bike)
      BikeCreator.new(b_param).create_associations(bike)
    end
  end

  describe :clear_bike do
    it "should remove the existing bike and transfer the errors to a new active record object" do 
      b_param = BParam.new
      bike = FactoryGirl.create(:bike)
      bike.errors.add(:rando_error, "LOLZ")
      BikeCreatorBuilder.any_instance.should_receive(:build).and_return(Bike.new)
      creator = BikeCreator.new(b_param).clear_bike(bike)
      creator.errors.messages[:rando_error].should_not be_nil
      Bike.where(id: bike.id).should be_empty
    end
  end

  describe :validate_record do
    it "should call remove associations if the bike was created and there are errors" do 
      b_param = BParam.new
      bike = Bike.new 
      b_param.stub(:bike).and_return(bike)
      bike.stub(:errors).and_return(messages: "some errors")
      creator = BikeCreator.new(b_param)
      creator.should_receive(:clear_bike).and_return(bike)
      creator.validate_record(bike)
    end

    it "should call delete the already existing bike if one exists" do 
      # This is to clean up duplicates, people press the 'add bike button' many times when its slow to respond
      b_param = BParam.new
      bike = FactoryGirl.create(:bike)
      bike1 = Bike.new 
      b_param.stub(:created_bike).and_return(bike1)
      BikeCreator.new(b_param).validate_record(bike).should eq(bike1)
      Bike.where(id: bike1.id).should be_empty
    end

    it "should associate the b_param with the bike and clear the bike_errors if the bike is created" do 
      b_param = BParam.new
      bike = Bike.new
      b_param.stub(:id).and_return(42)
      bike.stub(:id).and_return(69)
      bike.stub(:errors).and_return(nil)
      b_param.should_receive(:update_attributes).with(created_bike_id: 69, bike_errors: nil)
      BikeCreator.new(b_param).validate_record(bike)
    end
  end

  describe :save_bike do 
    it "should create a bike with the parameters it is passed and return it" do
      propulsion_type = FactoryGirl.create(:propulsion_type)
      cycle_type = FactoryGirl.create(:cycle_type)
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      manufacturer = FactoryGirl.create(:manufacturer)
      color = FactoryGirl.create(:color)
      handlebar_type = FactoryGirl.create(:handlebar_type)
      wheel_size = FactoryGirl.create(:wheel_size)
      b_param = BParam.new
      creator = BikeCreator.new(b_param)
      creator.should_receive(:create_associations).and_return(true)
      creator.should_receive(:validate_record).and_return(true)
      new_bike = Bike.new(
        creation_organization_id: organization.id,
        propulsion_type_id: propulsion_type.id,
        "cycle_type_id"=>cycle_type.id,
        "serial_number"=>"BIKE TOKENd",
        "manufacturer_id"=>manufacturer.id,
        "rear_tire_narrow"=>"true",
        "rear_wheel_size_id"=>wheel_size.id,
        "primary_frame_color_id"=>color.id,
        "handlebar_type_id"=>handlebar_type,
        "creator"=>user
      )
      lambda {
        creator.save_bike(new_bike)
      }.should change(Bike, :count).by(1)
    end
  end

  describe :new_bike do 
    it "should call the required methods" do
      creator = BikeCreator.new()
      creator.should_receive(:build_new_bike).and_return(true)
      creator.new_bike
    end
  end

  describe :create_bike do 
    it "should save the bike" do 
      b_param = BParam.new
      bike = Bike.new 
      creator = BikeCreator.new(b_param)
      creator.should_receive(:build_bike).at_least(1).times.and_return(bike)
      bike.should_receive(:save).and_return(true)
      creator.create_bike
    end

    it "should return the bike instead of saving if the bike has payment_required errors" do 
      b_param = BParam.new
      bike = Bike.new 
      creator = BikeCreator.new(b_param)
      bike.stub(:payment_required).and_return(true)
      creator.should_receive(:build_bike).and_return(bike)
      bike.should_not_receive(:save)
      creator.create_bike
    end

    it "should return the bike instead of saving if the bike has errors" do 
      b_param = BParam.new
      bike = Bike.new(serial_number: "LOLZ")
      bike.errors.add(:errory, "something")
      creator = BikeCreator.new(b_param)
      creator.should_receive(:build_bike).and_return(bike)
      response = creator.create_bike
      response.errors[:errory].should eq(["something"])
    end
  end

  describe :create_paid_bike do 
    it "should set the bike as paid" do 
      b_param = BParam.new
      bike = Bike.new 
      creator = BikeCreator.new(b_param)
      creator.should_receive(:build_bike).at_least(1).times.and_return(bike)
      bike.should_receive(:save).and_return(true)
      creator.create_paid_bike
      bike.verified.should be_true
      bike.paid_for.should be_true
      bike.payment_required.should be_false
    end
  end

end