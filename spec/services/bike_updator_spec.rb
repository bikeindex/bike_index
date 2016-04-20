require 'spec_helper'

describe BikeUpdator do
  describe 'find_bike' do
    it "raises an error if it can't find the bike" do
      expect {BikeUpdator.new(b_params: {id: 696969}).find_bike}.to raise_error(BikeUpdatorError)
    end
    it "finds the bike from the bike_params" do
      bike = FactoryGirl.create(:bike)
      response = BikeUpdator.new(b_params: {id: bike.id}).find_bike
      expect(response).to eq(bike)
    end
  end

  describe 'ensure_ownership!' do
    it "raises an error if the user doesn't own the bike" do
      ownership = FactoryGirl.create(:ownership)
      user = FactoryGirl.create(:user)
      bike = ownership.bike
      expect {BikeUpdator.new(user: user, b_params: {id: bike.id}).ensure_ownership!}.to raise_error(BikeUpdatorError)
    end

    it "returns true if the bike is owned by the user" do
      ownership = FactoryGirl.create(:ownership)
      user = ownership.creator
      bike = ownership.bike
      expect(BikeUpdator.new(user: user, b_params: {id: bike.id}).ensure_ownership!).to be_truthy
    end
  end

  describe 'update_stolen_record' do
    it "calls update_stolen_record with the date_stolen_input if it exists" do
      FactoryGirl.create(:country, iso: "US")
      bike = FactoryGirl.create(:bike, stolen: true)
      updator = BikeUpdator.new(b_params: {id: bike.id, bike: {date_stolen_input: "07-09-2000"}})
      updator.update_stolen_record
      csr = bike.find_current_stolen_record
      expect(csr.date_stolen).to eq(DateTime.strptime("07-09-2000 06", "%m-%d-%Y %H"))
    end
    it "creates a stolen record if one doesn't exist" do
      FactoryGirl.create(:country, iso: "US")
      bike = FactoryGirl.create(:bike)
      BikeUpdator.new(b_params: {id: bike.id, bike: {stolen: true}}).update_stolen_record
      expect(bike.stolen_records.count).not_to be_nil
    end
  end

  describe 'update_ownership' do
    it "calls create_ownership if the email has changed" do
      bike = FactoryGirl.create(:bike)
      user = FactoryGirl.create(:user)
      expect(bike.updator_id).to be_nil
      update_bike = BikeUpdator.new(b_params: {id: bike.id, bike: {owner_email: "another@email.co"}}, user: user)
      expect_any_instance_of(OwnershipCreator).to receive(:create_ownership)
      update_bike.update_ownership
      bike.reload
      expect(bike.updator).to eq(user)
    end

    it "does not call create_ownership if the email hasn't changed" do
      bike = FactoryGirl.create(:bike, owner_email: "another@email.co")
      update_bike = BikeUpdator.new(b_params: {id: bike.id, bike: {owner_email: "another@email.co"}})
      expect_any_instance_of(OwnershipCreator).not_to receive(:create_ownership)
      update_bike.update_ownership
    end
  end

  describe 'update_available_attributes' do
    it "does not let protected attributes be updated" do
      FactoryGirl.create(:country, iso: "US")
      organization = FactoryGirl.create(:organization)
      bike = FactoryGirl.create(:bike,
        creation_organization_id: organization.id,
        example: true,
        owner_email: 'foo@bar.com')
      ownership = FactoryGirl.create(:ownership, bike: bike)
      user = ownership.creator
      new_creator = FactoryGirl.create(:user)
      og_bike = bike
      bike_params = {
        description: "something long",
        serial_number: "69",
        manufacturer_id: 69,
        manufacturer_other: "Uggity Buggity",
        creator: new_creator,
        creation_organization_id: 69,
        example: false,
        hidden: true,
        stolen: true,
        owner_email: ' ',
      }
      BikeUpdator.new(user: user, b_params: {id: bike.id, bike: bike_params}).update_available_attributes
      expect(bike.reload.serial_number).to eq(og_bike.serial_number)
      expect(bike.manufacturer_id).to eq(og_bike.manufacturer_id)
      expect(bike.manufacturer_other).to eq(og_bike.manufacturer_other)
      expect(bike.creation_organization_id).to eq(og_bike.creation_organization_id)
      expect(bike.creator).to eq(og_bike.creator)
      expect(bike.example).to eq(og_bike.example)
      expect(bike.hidden).to be_falsey
      expect(bike.description).to eq("something long")
      expect(bike.owner_email).to eq('foo@bar.com')
    end

    it "marks a bike user hidden" do
      organization = FactoryGirl.create(:organization)
      bike = FactoryGirl.create(:bike, creation_organization_id: organization.id, example: true)
      ownership = FactoryGirl.create(:ownership, bike: bike)
      user = ownership.creator
      new_creator = FactoryGirl.create(:user)
      expect(bike.user_hidden).to be_falsey
      bike_params = {marked_user_hidden: true}
      BikeUpdator.new(user: user, b_params: {id: bike.id, bike: bike_params}).update_available_attributes
      expect(bike.reload.hidden).to be_truthy
      expect(bike.user_hidden).to be_truthy
    end

    it "Actually, for now, we let anyone mark anything not stolen" do
      bike = FactoryGirl.create(:bike, stolen: true)
      ownership = FactoryGirl.create(:ownership, bike: bike)
      user = ownership.creator
      new_creator = FactoryGirl.create(:user)
      bike_params = {stolen: false}
      update_bike = BikeUpdator.new(user: user, b_params: {id: bike.id, bike: bike_params})
      expect(update_bike).to receive(:update_ownership).and_return(true)
      update_bike.update_available_attributes
      expect(bike.reload.stolen).not_to be_truthy
    end

    it "updates the bike and set year to nothing if year nil" do
      bike = FactoryGirl.create(:bike, year: 2014)
      ownership = FactoryGirl.create(:ownership, bike: bike)
      user = ownership.creator
      new_creator = FactoryGirl.create(:user)
      bike_params = {coaster_brake: true, year: nil, :components_attributes =>{"1387762503379"=>{"ctype_id"=>"", "front"=>"0", "rear"=>"0", "ctype_other"=>"", "description"=>"", "manufacturer_id"=>"", "model_name"=>"", "manufacturer_other"=>"", "year"=>"", "serial_number"=>"", "_destroy"=>"0"}}}
      update_bike = BikeUpdator.new(user: user, b_params: {id: bike.id, bike: bike_params})
      expect(update_bike).to receive(:update_ownership).and_return(true)
      update_bike.update_available_attributes
      expect(bike.reload.coaster_brake).to be_truthy
      expect(bike.year).to be_nil
      expect(bike.components.count).to eq(0)
    end

    it "updates the bike sets is_for_sale to false" do
      bike = FactoryGirl.create(:bike, is_for_sale: true)
      ownership = FactoryGirl.create(:ownership, bike: bike)
      user = ownership.creator
      new_creator = FactoryGirl.create(:user)
      update_bike = BikeUpdator.new(user: user, b_params: {id: bike.id, bike: {owner_email: new_creator.email}})
      update_bike.update_available_attributes
      expect(bike.reload.is_for_sale).to be_falsey
    end
  end

  it "enque listing order working" do
    Sidekiq::Testing.fake!
    bike = FactoryGirl.create(:bike, stolen: true)
    ownership = FactoryGirl.create(:ownership, bike: bike)
    user = ownership.creator
    new_creator = FactoryGirl.create(:user)
    bike_params = {stolen: false}
    update_bike = BikeUpdator.new(user: user, b_params: {id: bike.id, bike: bike_params})
    expect(update_bike).to receive(:update_ownership).and_return(true)
    expect {
      update_bike.update_available_attributes
    }.to change(ListingOrderWorker.jobs, :size).by(2)
  end
end
