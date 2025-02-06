require "rails_helper"

RSpec.describe BikeUpdator do
  describe "find_bike" do
    it "raises an error if it can't find the bike" do
      expect { BikeUpdator.new(b_params: {id: 696969}).find_bike }.to raise_error(BikeUpdatorError)
    end
    it "finds the bike from the bike_params" do
      bike = FactoryBot.create(:bike)
      response = BikeUpdator.new(b_params: {id: bike.id}.as_json).find_bike
      expect(response).to eq(bike)
    end
  end

  describe "ensure_ownership!" do
    it "raises an error if the user doesn't own the bike" do
      ownership = FactoryBot.create(:ownership)
      user = FactoryBot.create(:user)
      bike = ownership.bike
      expect { BikeUpdator.new(user: user, b_params: {id: bike.id}.as_json).send(:ensure_ownership!) }.to raise_error(BikeUpdatorError)
    end

    it "returns true if the bike is owned by the user" do
      ownership = FactoryBot.create(:ownership)
      user = ownership.creator
      bike = ownership.bike
      expect(BikeUpdator.new(user: user, b_params: {id: bike.id}.as_json).send(:ensure_ownership!)).to be_truthy
    end
  end

  describe "update_ownership" do
    let(:email) { "something@fake.com" }
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, owner_email: email) }
    let(:user) { bike.user }
    let(:ownership) { bike.ownerships.first }
    it "calls create_ownership if the email has changed" do
      expect(bike.reload.updator_id).to be_nil
      expect(bike.user_id).to be_present
      expect(Ownership.count).to eq 1
      update_bike = BikeUpdator.new(b_params: {id: bike.id, bike: {owner_email: "another@email.co"}}.as_json, user: user)
      update_bike.update_ownership
      bike.reload
      expect(bike.updator).to eq(user)
      expect(Ownership.count).to eq 2
    end
    context "email doesn't change" do
      let(:email) { "another@email.co" }
      it "does not call create_ownership if the email hasn't changed" do
        bike.reload
        expect(Ownership.count).to eq 1
        update_bike = BikeUpdator.new(b_params: {id: bike.id, bike: {owner_email: "another@EMAIL.co"}}.as_json)
        update_bike.update_ownership
        expect(Ownership.count).to eq 1
      end
    end

    context "organized" do
      let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, owner_email: email) }
      let(:organization) { bike.organizations.first }
      it "does not pass organization" do
        expect(bike.reload.current_ownership.organization).to be_present
        expect(bike.created_at).to be < Time.current - 1.hour
        expect(bike.not_updated_by_user?).to be_truthy
        expect(bike.updator_id).to be_blank
        expect(user.member_of?(organization)).to be_falsey
        expect(ownership.reload.organization_pre_registration?).to be_falsey
        expect(ownership.origin).to eq "web"
        expect(ownership.organization_id).to eq organization.id
        update_bike = BikeUpdator.new(b_params: {id: bike.id, bike: {owner_email: "another@EMAIL.co"}}.as_json, user: user)
        update_bike.update_ownership
        expect(Ownership.count).to eq 2
        new_ownership = bike.reload.current_ownership
        expect(new_ownership.id).to_not eq ownership.id
        expect(new_ownership.organization_id).to be_blank
        expect(new_ownership.origin).to eq "transferred_ownership"
        expect(bike.bike_organizations.count).to eq 1
        expect(bike.bike_organizations.first.organization).to eq organization
        expect(bike.bike_organizations.first.can_edit_claimed).to be_truthy
        expect(bike.reload.updated_by_user_at).to be > Time.current - 1
        expect(bike.not_updated_by_user?).to be_falsey
        expect(bike.updator_id).to eq user.id
      end
      context "user is an organization member" do
        it "passes users organization" do
          FactoryBot.create(:organization_user_claimed, user: user, organization: organization)
          expect(bike.reload.current_ownership.organization).to be_present
          expect(user.reload.member_of?(organization)).to be_truthy
          expect(ownership.reload.organization_pre_registration?).to be_falsey
          expect(ownership.origin).to eq "web"
          expect(ownership.organization_id).to eq organization.id
          update_bike = BikeUpdator.new(b_params: {id: bike.id, bike: {owner_email: "another@EMAIL.co"}}.as_json, user: user)
          update_bike.update_ownership
          expect(Ownership.count).to eq 2
          new_ownership = bike.reload.current_ownership
          expect(new_ownership.id).to_not eq ownership.id
          expect(new_ownership.organization_id).to eq organization.id
          expect(new_ownership.origin).to eq "transferred_ownership"
          expect(bike.bike_organizations.count).to eq 1
          expect(bike.bike_organizations.first.organization).to eq organization
          expect(bike.bike_organizations.first.can_edit_claimed).to be_truthy
        end
      end
    end
  end

  describe "update_available_attributes" do
    it "does not let protected attributes be updated" do
      FactoryBot.create(:country, iso: "US")
      organization = FactoryBot.create(:organization)
      bike = FactoryBot.create(:bike,
        creation_organization_id: organization.id,
        example: true,
        owner_email: "foo@bar.com")
      ownership = FactoryBot.create(:ownership, bike: bike)
      user = ownership.creator
      new_creator = FactoryBot.create(:user)
      og_bike = bike
      bike_params = {
        description: "something long",
        serial_number: "69",
        manufacturer_id: 69,
        manufacturer_other: "Uggity Buggity",
        creator: new_creator,
        creation_organization_id: 69,
        example: false,
        user_hidden: true,
        owner_email: " "
      }
      BikeUpdator.new(user: user, b_params: {id: bike.id, bike: bike_params}.as_json).update_available_attributes
      expect(bike.reload.serial_number).to eq(og_bike.serial_number)
      expect(bike.manufacturer_id).to eq(og_bike.manufacturer_id)
      expect(bike.manufacturer_other).to eq(og_bike.manufacturer_other)
      expect(bike.creation_organization_id).to eq(og_bike.creation_organization_id)
      expect(bike.creator).to eq(og_bike.creator)
      expect(bike.example).to eq(og_bike.example)
      expect(bike.user_hidden).to be_falsey
      expect(bike.description).to eq("something long")
      expect(bike.owner_email).to eq("foo@bar.com")
      expect(bike.status).to eq "status_with_owner"
    end

    it "marks a bike stolen with the date_stolen" do
      FactoryBot.create(:country, iso: "US")
      bike = FactoryBot.create(:bike, :with_ownership)
      updator = BikeUpdator.new(user: bike.creator, b_params: {id: bike.id, bike: {date_stolen: 963205199}}.as_json)
      updator.update_available_attributes
      bike.reload
      expect(bike.status).to eq "status_stolen"
      csr = bike.fetch_current_stolen_record
      expect(csr.date_stolen.to_i).to be_within(1).of 963205199
    end

    it "marks a bike user hidden" do
      organization = FactoryBot.create(:organization)
      bike = FactoryBot.create(:bike, creation_organization_id: organization.id, example: true)
      ownership = FactoryBot.create(:ownership, bike: bike)
      user = ownership.creator
      FactoryBot.create(:user)
      expect(bike.user_hidden).to be_falsey
      bike_params = {marked_user_hidden: true}
      BikeUpdator.new(user: user, b_params: {id: bike.id, bike: bike_params}.as_json).update_available_attributes
      expect(bike.reload.user_hidden).to be_truthy
    end

    it "updates the bike and set year to nothing if year nil" do
      bike = FactoryBot.create(:bike, year: 2014)
      ownership = FactoryBot.create(:ownership, bike: bike)
      user = ownership.creator
      FactoryBot.create(:user)
      bike_params = {coaster_brake: true, year: nil, components_attributes: {"1387762503379" => {"ctype_id" => "", "front" => "0", "rear" => "0", "ctype_other" => "", "description" => "", "manufacturer_id" => "", "model_name" => "", "manufacturer_other" => "", "year" => "", "serial_number" => "", "_destroy" => "0"}}}
      update_bike = BikeUpdator.new(user: user, b_params: {id: bike.id, bike: bike_params}.as_json)
      expect(update_bike).to receive(:update_ownership).and_return(true)
      update_bike.update_available_attributes
      expect(bike.reload.coaster_brake).to be_truthy
      expect(bike.year).to be_nil
      expect(bike.components.count).to eq(0)
    end

    it "updates the bike sets is_for_sale and address_set_manually to false" do
      bike = FactoryBot.create(:bike, is_for_sale: true, address_set_manually: true)
      ownership = FactoryBot.create(:ownership, bike: bike)
      user = ownership.creator
      new_creator = FactoryBot.create(:user)
      update_bike = BikeUpdator.new(user: user, b_params: {id: bike.id, bike: {owner_email: new_creator.email}}.as_json)
      update_bike.update_available_attributes
      bike.reload
      expect(bike.is_for_sale).to be_falsey
      expect(bike.address_set_manually).to be_falsey
    end
  end

  it "enque listing order working" do
    Sidekiq::Testing.fake!
    bike = FactoryBot.create(:bike)
    ownership = FactoryBot.create(:ownership, bike: bike)
    user = ownership.creator
    FactoryBot.create(:user)
    update_bike = BikeUpdator.new(user: user, b_params: {id: bike.id, bike: {}}.as_json)
    expect(update_bike).to receive(:update_ownership).and_return(true)
    expect {
      update_bike.update_available_attributes
    }.to change(AfterBikeSaveWorker.jobs, :size).by(1)
  end
end
