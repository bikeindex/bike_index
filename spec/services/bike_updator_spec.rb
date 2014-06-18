require 'spec_helper'

describe BikeUpdator do
  describe :find_bike do 
    it "should raise an error if it can't find the bike" do 
      expect {BikeUpdator.new(b_params: {id: 696969}).find_bike}.to raise_error(BikeUpdatorError)
    end
    it "should find the bike from the bike_params" do 
      bike = FactoryGirl.create(:bike)
      response = BikeUpdator.new(b_params: {id: bike.id}).find_bike
      response.should eq(bike)
    end
  end

  describe :ensure_ownership! do 
    it "should raise an error if the user doesn't own the bike" do
      ownership = FactoryGirl.create(:ownership)
      user = FactoryGirl.create(:user)
      bike = ownership.bike
      expect {BikeUpdator.new(user: user, b_params: {id: bike.id}).ensure_ownership!}.to raise_error(BikeUpdatorError)
    end

    it "should return true if the bike is owned by the user" do 
      ownership = FactoryGirl.create(:ownership)
      user = ownership.creator
      bike = ownership.bike
      expect{ BikeUpdator.new(user: user, b_params: {id: bike.id}).ensure_ownership!}.to be_true
    end
  end

  describe :update_stolen_record do 
    it "should call update_stolen_record with the date_stolen_input if it exists" do 
      bike = FactoryGirl.create(:bike, stolen: true)
      BikeUpdator.new(b_params: {id: bike.id, bike: {date_stolen_input: "07-09-2000"}}).update_stolen_record
      bike.current_stolen_record.date_stolen.should eq(DateTime.strptime("07-09-2000 06", "%m-%d-%Y %H"))
    end
    it "should create a stolen record if one doesn't exist" do 
      bike = FactoryGirl.create(:bike)
      BikeUpdator.new(b_params: {id: bike.id, bike: {stolen: true}}).update_stolen_record
      bike.stolen_records.count.should_not be_nil
    end
  end

  describe :update_ownership do 
    it "should call create_ownership if the email has changed" do 
      bike = FactoryGirl.create(:bike)
      update_bike = BikeUpdator.new(b_params: {id: bike.id, bike: {owner_email: "another@email.co"}})
      OwnershipCreator.any_instance.should_receive(:create_ownership)
      update_bike.update_ownership
    end

    it "should not call create_ownership if the email hasn't changed" do 
      bike = FactoryGirl.create(:bike, owner_email: "another@email.co")
      update_bike = BikeUpdator.new(b_params: {id: bike.id, bike: {owner_email: "another@email.co"}})
      OwnershipCreator.any_instance.should_not_receive(:create_ownership)
      update_bike.update_ownership
    end
  end

  describe :update_available_attributes do 
    it "should not let protected attributes be updated" do 
      organization = FactoryGirl.create(:organization)
      bike = FactoryGirl.create(:bike, creation_organization_id: organization.id, verified: true, example: true)
      ownership = FactoryGirl.create(:ownership, bike: bike)
      user = ownership.creator
      new_creator = FactoryGirl.create(:user)
      og_bike = bike
      bike_params = {description: "something long", serial_number: "69", manufacturer_id: 69, manufacturer_other: "Uggity Buggity", creator: new_creator, creation_organization_id: 69, example: false, stolen: true}
      BikeUpdator.new(user: user, b_params: {id: bike.id, bike: bike_params}).update_available_attributes
      bike.reload.serial_number.should eq(og_bike.serial_number)
      bike.manufacturer_id.should eq(og_bike.manufacturer_id)
      bike.manufacturer_other.should eq(og_bike.manufacturer_other)
      bike.creation_organization_id.should eq(og_bike.creation_organization_id)
      bike.creator.should eq(og_bike.creator)
      bike.example.should eq(og_bike.example)
      # bike.stolen.should be_true
      bike.verified.should be_true
      bike.description.should eq("something long")
    end

    # it "should not let bikes that weren't created by an organization become non-stolen" do 
    it "Actually, for now, we let anyone mark anything not stolen" do 
      bike = FactoryGirl.create(:bike, stolen: true)
      ownership = FactoryGirl.create(:ownership, bike: bike)
      user = ownership.creator
      new_creator = FactoryGirl.create(:user)
      bike_params = {stolen: false}
      update_bike = BikeUpdator.new(user: user, b_params: {id: bike.id, bike: bike_params})
      update_bike.should_receive(:update_ownership).and_return(true)
      update_bike.update_available_attributes
      bike.reload.stolen.should_not be_true
    end

    it "should update the bike and set year to nothing if year nil" do 
      # I was having trouble setting year to nil and having it update.
      # So, now we're setting it to 69 if there is no year
      bike = FactoryGirl.create(:bike, year: 2014)
      ownership = FactoryGirl.create(:ownership, bike: bike)
      user = ownership.creator
      new_creator = FactoryGirl.create(:user)
      bike_params = {coaster_brake: true, year: nil, :components_attributes =>{"1387762503379"=>{"ctype_id"=>"", "front"=>"0", "rear"=>"0", "ctype_other"=>"", "description"=>"", "manufacturer_id"=>"", "model_name"=>"", "manufacturer_other"=>"", "year"=>"", "serial_number"=>"", "_destroy"=>"0"}}}
      update_bike = BikeUpdator.new(user: user, b_params: {id: bike.id, bike: bike_params})
      update_bike.should_receive(:update_ownership).and_return(true)
      update_bike.update_available_attributes
      bike.reload.coaster_brake.should be_true
      bike.reload.year.should be_nil
      bike.components.count.should eq(0)
    end
  end

  it "enque listing order working" do
    Sidekiq::Worker.clear_all
    bike = FactoryGirl.create(:bike, stolen: true)
    ownership = FactoryGirl.create(:ownership, bike: bike)
    user = ownership.creator
    new_creator = FactoryGirl.create(:user)
    bike_params = {stolen: false}
    update_bike = BikeUpdator.new(user: user, b_params: {id: bike.id, bike: bike_params})
    update_bike.should_receive(:update_ownership).and_return(true)
    expect {
      update_bike.update_available_attributes
    }.to change(ListingOrderWorker.jobs, :size).by(1)
  end
end
