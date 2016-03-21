require 'spec_helper'

describe BikeCreatorAssociator do

  describe :create_ownership do 
    it "calls create ownership" do 
      b_param = BParam.new
      bike = Bike.new
      b_param.stub(:params).and_return({bike: bike})
      b_param.stub(:creator).and_return('creator')
      # OwnershipCreator.any_instance.should_receive(:initialize).with(bike: bike, creator: 'creator', send_email: true)
      OwnershipCreator.any_instance.should_receive(:create_ownership).and_return(true)
      BikeCreatorAssociator.new(b_param).create_ownership(bike)
    end
    it "calls create ownership with send_email false if b_param has that" do 
      b_param = BParam.new
      bike = Bike.new
      b_param.stub(:params).and_return({bike: {send_email: false}})
      b_param.stub(:creator).and_return('creator')
      # OwnershipCreator.any_instance.should_receive(:initialize).with(bike: bike, creator: 'creator', send_email: false)
      OwnershipCreator.any_instance.should_receive(:create_ownership).and_return(true)
      BikeCreatorAssociator.new(b_param).create_ownership(bike)
    end
  end

  describe :create_components do 
    it "calls create components" do 
      b_param = BParam.new
      bike = Bike.new 
      ComponentCreator.any_instance.should_receive(:create_components_from_params).and_return(true)
      BikeCreatorAssociator.new(b_param).create_components(bike)
    end
  end

  describe :create_normalized_serial_segments do 
    it "calls create components" do 
      b_param = BParam.new
      bike = Bike.new 
      SerialNormalizer.any_instance.should_receive(:save_segments).and_return(true)
      BikeCreatorAssociator.new(b_param).create_normalized_serial_segments(bike)
    end
  end

  describe :create_stolen_record do
    it "calls create stolen record and set_creation_organization" do 
      b_param = BParam.new
      bike = Bike.new 
      bike.stub(:creation_organization).and_return(true)
      StolenRecordUpdator.any_instance.should_receive(:create_new_record).and_return(true)
      StolenRecordUpdator.any_instance.should_receive(:set_creation_organization).and_return(true)
      BikeCreatorAssociator.new(b_param).create_stolen_record(bike)
    end
  end

  describe :add_other_listings do 
    it "calls create stolen record and set_creation_organization" do 
      b_param = BParam.new
      bike = FactoryGirl.create(:bike)
      urls = ['http://some_blog.com', 'http://some_thing.com']
      b_param.stub(:params).and_return({bike: {other_listing_urls: urls}})
      BikeCreatorAssociator.new(b_param).add_other_listings(bike)
      bike.other_listings.reload.pluck(:url).should eq(urls)
    end
  end

  describe :attach_photo do 
    it "creates public images for the attached image" do 
      bike = FactoryGirl.create(:bike)
      b_param = FactoryGirl.create(:b_param)
      test_photo = Rack::Test::UploadedFile.new(File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg')))
      b_param.image = test_photo
      b_param.save 
      b_param.image.should be_present
      b_param.params = p
      BikeCreatorAssociator.new(b_param).attach_photo(bike)
      bike.public_images.count.should eq(1)
    end
  end

  # describe :add_uploaded_image do 
  #   it "associates the public image" do 
  #     bike = FactoryGirl.create(:bike)
  #     b_param = FactoryGirl.create(:b_param)
  #     b_param.params = {bike: {bike_image: File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg'))}}
  #     b_param.save
  #     BikeCreatorAssociator.new(b_param).add_uploaded_image(bike)
  #     bike.reload.public_images.count.should eq(1)
  #   end
  # end

  describe :associate do 
    it "calls the required methods" do
      bike = Bike.new
      creator = BikeCreatorAssociator.new()
      bike.stub(:stolen).and_return(true)
      creator.should_receive(:create_ownership).and_return(bike)
      creator.should_receive(:create_stolen_record).and_return(bike)
      creator.should_receive(:create_components).and_return(bike)
      creator.should_receive(:create_normalized_serial_segments).and_return(bike)
      creator.should_receive(:attach_photo)
      creator.should_receive(:attach_photos)
      creator.should_receive(:add_other_listings)
      creator.associate(bike)
    end
    it "rescues from the error and add the message to the bike" do 
      bike = Bike.new
      creator = BikeCreatorAssociator.new()
      bike.stub(:stolen).and_return(true)
      bike.stub(:create_stolen_record).and_raise(StolenRecordError, "Gobledy gook")
      creator.associate(bike)
      bike.errors.messages[:association_error].should_not be_nil
    end
  end

end
