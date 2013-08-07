require 'spec_helper'

describe BikeCreatorAssociator do

  describe :create_ownership do 
    it "should call create ownership" do 
      b_param = BParam.new
      bike = Bike.new 
      OwnershipCreator.any_instance.should_receive(:create_ownership).and_return(true)
      BikeCreatorAssociator.new(b_param).create_ownership(bike)
    end
  end

  describe :create_stolen_record do 
    it "should call create ownership" do 
      b_param = BParam.new
      bike = Bike.new 
      StolenRecordUpdator.any_instance.should_receive(:create_new_record).and_return(true)
      BikeCreatorAssociator.new(b_param).create_stolen_record(bike)
    end
  end

  describe :update_bike_token do 
    it "should set the bike_token to the bike" do 
      b_param = BParam.new
      bike_token = FactoryGirl.create(:bike_token)
      bike = Bike.new 
      b_param.stub(:bike_token_id).and_return(bike_token.id)
      bike.stub(:id).and_return(2)
      BikeCreatorAssociator.new(b_param).update_bike_token(bike)
      bike_token.reload.bike_id.should eq(2)
    end
  end

  # describe :add_uploaded_image do 
  #   it "should associate the public image" do 
  #     bike = FactoryGirl.create(:bike)
  #     b_param = FactoryGirl.create(:b_param)
  #     b_param.params = {:bike => {bike_image: File.open(File.join(Rails.root, 'spec', 'factories', 'bike.jpg'))}}
  #     b_param.save
  #     BikeCreatorAssociator.new(b_param).add_uploaded_image(bike)
  #     bike.reload.public_images.count.should eq(1)
  #   end
  # end

  describe :associate do 
    it "should call the required methods" do
      bike = Bike.new
      creator = BikeCreatorAssociator.new()
      bike.stub(:stolen).and_return(true)
      bike.stub(:created_with_token).and_return(true)
      creator.should_receive(:create_ownership).and_return(bike)
      creator.should_receive(:create_stolen_record).and_return(bike)
      creator.should_receive(:update_bike_token).and_return(bike)
      # creator.should_receive(:add_uploaded_image).and_return(bike)
      creator.associate(bike)
    end
    it "should rescue from the error and add the message to the bike" do 
      bike = Bike.new
      creator = BikeCreatorAssociator.new()
      bike.stub(:stolen).and_return(true)
      bike.stub(:create_stolen_record).and_raise(StolenRecordError, "Gobledy gook")
      creator.associate(bike)
      bike.errors.messages[:association_error].should_not be_nil
    end
  end

end