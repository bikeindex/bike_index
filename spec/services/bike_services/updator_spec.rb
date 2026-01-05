require "rails_helper"

RSpec.describe BikeServices::Updator do
  let(:params) { ActionController::Parameters.new(passed_params) }

  describe "ensure_ownership!" do
    it "raises an error if the user doesn't own the bike" do
      ownership = FactoryBot.create(:ownership)
      user = FactoryBot.create(:user)
      bike = ownership.bike
      expect { BikeServices::Updator.new(user: user, bike:, permitted_params: {id: bike.id}.as_json).send(:ensure_ownership!) }.to raise_error(BikeServices::UpdatorError)
    end

    it "returns true if the bike is owned by the user" do
      ownership = FactoryBot.create(:ownership)
      user = ownership.creator
      bike = ownership.bike
      expect(BikeServices::Updator.new(user:, bike:, permitted_params: {id: bike.id}.as_json).send(:ensure_ownership!)).to be_truthy
    end
  end

  describe "update_ownership" do
    let(:email) { "something@fake.com" }
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_primary_activity, owner_email: email) }
    let(:user) { bike.user }
    let(:ownership) { bike.ownerships.first }
    let(:passed_params) { {id: bike.id, bike: {owner_email: "another@email.co"}} }
    it "creates ownership if the email has changed" do
      expect(bike.reload.updator_id).to be_nil
      expect(bike.user_id).to be_present
      expect(Ownership.count).to eq 1
      update_bike = BikeServices::Updator.new(bike:, params:, user:)
      update_bike.send(:update_ownership)
      bike.save
      bike.reload
      expect(bike.updator).to eq(user)
      expect(Ownership.count).to eq 2
    end
    context "email doesn't change" do
      let(:email) { "another@email.co" }
      it "does not create ownership if the email hasn't changed" do
        bike.reload
        expect(Ownership.count).to eq 1
        update_bike = BikeServices::Updator.new(bike:, user:, params:)
        update_bike.send(:update_ownership)
        expect(Ownership.count).to eq 1
      end
    end

    # NOTE: This is intended as a fallback catch
    # There should be specific functionality added for handling sales
    context "when there is a marketplace listing" do
      let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item: bike) }

      it "updates the marketplace_listing to be removed" do
        expect(marketplace_listing.reload.status).to eq "draft"
        bike.update_column :is_for_sale, true
        Sidekiq::Job.clear_all

        expect(marketplace_listing.reload.bike_ownership&.id).to eq ownership.id
        expect(marketplace_listing.current?).to be_truthy
        expect do
          BikeServices::Updator.new(bike:, params:, user: user).update_available_attributes
        end.to change(Ownership, :count).by 1
        Sidekiq::Job.drain_all
        expect(marketplace_listing.reload.bike_ownership&.id).to eq ownership.id
        expect(marketplace_listing.end_at).to be_within(5).of Time.current
        expect(marketplace_listing.status).to eq "removed"
        expect(marketplace_listing.current?).to be_falsey
        expect(bike.reload.is_for_sale).to be_falsey
      end

      context "with published_at" do
        let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, item: bike) }
        it "updates the marketplace_listing to be removed" do
          expect(marketplace_listing.reload.status).to eq "for_sale"
          expect(bike.reload.is_for_sale).to be_truthy
          Sidekiq::Job.clear_all

          expect(marketplace_listing.current?).to be_truthy
          expect do
            BikeServices::Updator.new(bike:, params:, user: user).update_available_attributes
          end.to change(Ownership, :count).by 1
          Sidekiq::Job.drain_all
          expect(marketplace_listing.reload.bike_ownership&.id).to eq ownership.id
          expect(marketplace_listing.end_at).to be_within(5).of Time.current
          expect(marketplace_listing.status).to eq "sold" # guessed
          expect(marketplace_listing.current?).to be_falsey
          expect(bike.reload.is_for_sale).to be_falsey
        end
      end
    end

    context "organized" do
      let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, owner_email: email) }
      let(:organization) { bike.organizations.first }
      let(:new_ownership_attrs) do
        {organization_id: nil, origin: "transferred_ownership", status: "status_with_owner", impound_record_id: nil}
      end
      it "does not pass organization" do
        bike.update_column :updated_at, Time.current - 2.hours
        expect(bike.reload.current_ownership.organization).to be_present
        expect(bike.created_at).to be < Time.current - 1.hour
        expect(bike.not_updated_by_user?).to be_truthy
        expect(bike.updator_id).to be_blank
        expect(user.member_of?(organization)).to be_falsey
        expect(ownership.reload.organization_pre_registration?).to be_falsey
        expect(ownership.origin).to eq "web"
        expect(ownership.organization_id).to eq organization.id
        update_bike = BikeServices::Updator.new(bike:, permitted_params: {id: bike.id, bike: {owner_email: "another@EMAIL.co"}}.as_json, user: user)
        update_bike.send(:update_ownership)
        # Bike hasn't been saved
        expect(bike.updated_at).to be < Time.current - 1.hour
        bike.save
        expect(Ownership.count).to eq 2
        expect(bike.reload.current_ownership.id).to_not eq ownership.id
        expect(bike.current_ownership).to have_attributes(new_ownership_attrs)
        expect(bike.bike_organizations.count).to eq 1
        expect(bike.bike_organizations.first.organization).to eq organization
        expect(bike.bike_organizations.first.can_edit_claimed).to be_truthy
        expect(bike.updated_at).to be > Time.current - 2
        expect(bike.updated_by_user_at).to be > Time.current - 2
        expect(bike.not_updated_by_user?).to be_falsey
        expect(bike.updator_id).to eq user.id
      end
      context "bike is impounded" do
        let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, bike:, organization:) }
        let!(:organization_user) { FactoryBot.create(:organization_role_claimed, organization:).user }
        let(:impound_ownership_attrs) { new_ownership_attrs.merge(impound_record_id: impound_record.id, organization_id: organization.id) }
        it "creates a new ownership with status_with_owner" do
          expect(bike.reload.status).to eq "status_impounded"
          ProcessImpoundUpdatesJob.new.perform(impound_record.id)

          expect(bike.reload.current_ownership.organization).to be_present
          expect(bike.created_at).to be < Time.current - 1.hour
          expect(bike.not_updated_by_user?).to be_truthy
          expect(bike.updator_id).to be_blank
          expect(bike.status).to eq "status_impounded"
          expect(bike.current_ownership.status).to eq "status_with_owner"
          expect(bike.unregistered_parking_notification?).to be_falsey
          expect(bike.send(:authorization_requires_impound_organization?)).to be_truthy
          expect(user.member_of?(organization)).to be_falsey
          expect(bike.authorized?(user)).to be_falsey
          expect(organization_user.member_of?(organization)).to be_truthy
          expect(bike.authorized?(organization_user)).to be_truthy

          expect(ownership.reload.organization_pre_registration?).to be_falsey
          expect(ownership.origin).to eq "web"
          expect(ownership.organization_id).to eq organization.id

          Sidekiq::Job.clear_all
          expect do
            BikeServices::Updator.new(bike:, permitted_params: {id: bike.id, bike: {owner_email: "another@EMAIL.co"}}.as_json,
              user: organization_user).update_available_attributes
          end.to change(Ownership, :count).by(1)
            .and change(ImpoundRecordUpdate, :count).by(1)

          expect(ProcessImpoundUpdatesJob.jobs.count).to eq 1
          expect do
            Sidekiq::Job.drain_all
          end.to change(Ownership, :count).by(0)
            .and change(ActionMailer::Base.deliveries, :count).by 1 # Make sure only one transfer email is sent

          expect(Ownership.count).to eq 2
          expect(bike.reload.current_ownership.id).to_not eq ownership.id
          expect(bike.status).to eq "status_with_owner"
          expect(bike.current_impound_record).to be_blank
          expect(bike.current_ownership).to have_attributes(impound_ownership_attrs)
          expect(bike.current_ownership.new_registration?).to be_falsey
          expect(bike.bike_organizations.count).to eq 1
          expect(bike.bike_organizations.first.organization).to eq organization
          expect(bike.bike_organizations.first.can_edit_claimed).to be_truthy
          expect(bike.reload.updated_by_user_at).to be > Time.current - 1
          expect(bike.not_updated_by_user?).to be_falsey
          expect(bike.updator_id).to eq organization_user.id

          expect(impound_record.reload.resolved?).to be_truthy
        end
      end
      context "user is an organization member" do
        it "passes users organization" do
          FactoryBot.create(:organization_role_claimed, user: user, organization: organization)
          expect(bike.reload.current_ownership.organization).to be_present
          expect(user.reload.member_of?(organization)).to be_truthy
          expect(ownership.reload.organization_pre_registration?).to be_falsey
          expect(ownership.origin).to eq "web"
          expect(ownership.organization_id).to eq organization.id
          update_bike = BikeServices::Updator.new(bike:, permitted_params: {id: bike.id, bike: {owner_email: "another@EMAIL.co"}}.as_json, user: user)
          update_bike.send(:update_ownership)
          expect(Ownership.count).to eq 2
          expect(bike.reload.current_ownership.id).to_not eq ownership.id
          expect(bike.current_ownership).to have_attributes(new_ownership_attrs.merge(organization_id: organization.id))
          expect(bike.bike_organizations.count).to eq 1
          expect(bike.bike_organizations.first.organization).to eq organization
          expect(bike.bike_organizations.first.can_edit_claimed).to be_truthy
        end
      end
    end
  end

  describe "update_available_attributes" do
    it "does not let protected attributes be updated" do
      Country.united_states
      organization = FactoryBot.create(:organization)
      bike = FactoryBot.create(:bike, :with_ownership,
        creation_organization_id: organization.id,
        example: true,
        owner_email: "foo@bar.com")
      user = bike.creator
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
      BikeServices::Updator.new(user: user, bike:, permitted_params: {id: bike.id, bike: bike_params}.as_json).update_available_attributes
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
      Country.united_states
      bike = FactoryBot.create(:bike, :with_ownership)
      updator = BikeServices::Updator.new(user: bike.creator, bike:, permitted_params: {id: bike.id, bike: {date_stolen: 963205199}}.as_json)
      updator.update_available_attributes
      bike.reload
      expect(bike.status).to eq "status_stolen"
      csr = bike.fetch_current_stolen_record
      expect(csr.date_stolen.to_i).to be_within(1).of 963205199
    end

    it "marks a bike user hidden" do
      organization = FactoryBot.create(:organization)
      bike = FactoryBot.create(:bike, :with_ownership, creation_organization_id: organization.id, example: true)
      user = bike.creator
      expect(bike.user_hidden).to be_falsey
      bike_params = {marked_user_hidden: true}
      BikeServices::Updator.new(user:, bike:, permitted_params: {id: bike.id, bike: bike_params}.as_json).update_available_attributes
      expect(bike.reload.user_hidden).to be_truthy
    end

    it "updates the bike and set year to nothing if year nil" do
      bike = FactoryBot.create(:bike, :with_ownership, year: 2014)
      user = bike.creator
      bike_params = {coaster_brake: true, year: nil, components_attributes: {"1387762503379" => {"ctype_id" => "", "front" => "0", "rear" => "0", "ctype_other" => "", "description" => "", "manufacturer_id" => "", "model_name" => "", "manufacturer_other" => "", "year" => "", "serial_number" => "", "_destroy" => "0"}}}
      update_bike = BikeServices::Updator.new(user:, bike:, permitted_params: {id: bike.id, bike: bike_params}.as_json)
      # expect(update_bike).to receive(:update_current_ownership).and_return(true)
      update_bike.update_available_attributes
      expect(bike.reload.coaster_brake).to be_truthy
      expect(bike.year).to be_nil
      expect(bike.components.count).to eq(0)
    end

    it "updates the bike sets is_for_sale and address_set_manually to false" do
      bike = FactoryBot.create(:bike, :with_ownership, is_for_sale: true, address_set_manually: true)
      user = bike.creator
      new_owner = FactoryBot.create(:user)
      update_bike = BikeServices::Updator.new(user: user, bike:, permitted_params: {id: bike.id, bike: {owner_email: new_owner.email}}.as_json)
      update_bike.update_available_attributes
      bike.reload
      expect(bike.is_for_sale).to be_falsey
      expect(bike.address_set_manually).to be_falsey
    end
  end

  it "enqueue listing order working" do
    Sidekiq::Testing.fake!
    bike = FactoryBot.create(:bike, :with_ownership)
    user = bike.creator
    FactoryBot.create(:user)
    update_bike = BikeServices::Updator.new(user:, bike:, permitted_params: {id: bike.id, bike: {}}.as_json)
    expect(update_bike).to receive(:update_ownership).and_return(true)
    expect {
      update_bike.update_available_attributes
    }.to change(CallbackJob::AfterBikeSaveJob.jobs, :size).by(1)
  end

  describe "update_address_record" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let(:user) { bike.reload.user }
    let(:bike_params) { {description: "something long", address_record_attributes:} }
    let(:address_record_attributes) do
      {city: "Edmonton", region_string: "AB", postal_code: "T5P 4W1", country_id:,
       street: "15007 Stony Plain Rd", id: 12}
    end
    let(:update) do
      BikeServices::Updator.new(user: user, bike:, permitted_params: {id: bike.id, bike: bike_params}.as_json)
        .update_available_attributes
    end
    let!(:country_id) { Country.canada_id }
    let(:target_attributes) do
      # geocoder default_location coordinates
      address_record_attributes.except(:id).merge(kind: :bike, latitude: 40.7143528, longitude: -74.0059731)
    end
    it "creates an address_record" do
      expect(bike.reload.ownerships.count).to eq 1
      expect(bike.user_id).to eq user.id
      expect(AddressRecord.count).to eq 0
      expect { update }.to change(AddressRecord, :count).by(1).and change(Ownership, :count).by(0)

      expect(bike.reload.description).to eq "something long"
      expect(bike.address_set_manually).to be_truthy
      expect(bike.address_record).to match_hash_indifferently target_attributes
    end

    context "with existing address_record" do
      let!(:address_record) { FactoryBot.create(:address_record, :amsterdam, bike:, kind:) }
      let(:kind) { "bike" }
      it "updates the address_record" do
        expect(bike.reload.ownerships.count).to eq 1
        expect(bike.user_id).to eq user.id
        expect(AddressRecord.count).to eq 1
        expect { update }.to change(AddressRecord, :count).by(1).and change(Ownership, :count).by(0)

        expect(bike.reload.description).to eq "something long"
        expect(bike.address_set_manually).to be_truthy
        expect(bike.address_record).to match_hash_indifferently target_attributes
      end
      context "when existing address_record is kind: :ownership" do
        let(:kind) { "ownership" }

        it "creates a new address_record" do
          expect(bike.reload.ownerships.count).to eq 1
          expect(bike.user_id).to eq user.id
          expect(AddressRecord.count).to eq 1
          expect { update }.to change(AddressRecord, :count).by(1).and change(Ownership, :count).by(0)

          expect(bike.reload.description).to eq "something long"
          expect(bike.address_set_manually).to be_truthy
          expect(bike.address_record).to match_hash_indifferently target_attributes

          expect(address_record.reload.street).to eq "Spuistraat 134afd.Gesch."
        end
      end
    end

    # TODO: Remove this once backfill is finished - #2922
    context "legacy location attrs" do
      let(:bike_params) do
        {description: "something long", city: "Edmonton", zipcode: "T5P 4W1", country_id:, street: "15007 Stony Plain Rd"}
      end
      it "creates an address_record" do
        expect(bike.reload.ownerships.count).to eq 1
        expect(bike.user_id).to eq user.id
        expect(AddressRecord.count).to eq 0
        expect { update }.to change(AddressRecord, :count).by(1).and change(Ownership, :count).by(0)

        expect(bike.reload.description).to eq "something long"
        expect(bike.address_set_manually).to be_truthy
        expect(bike.address_record).to match_hash_indifferently target_attributes.except(:region_string)
      end
    end
  end
end
