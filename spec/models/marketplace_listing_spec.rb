require "rails_helper"

RSpec.describe MarketplaceListing, type: :model do
  it_behaves_like "address_recorded"

  describe "factory" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing) }

    it "is valid" do
      expect(marketplace_listing).to be_valid
      expect(marketplace_listing.reload.id).to be_present
      expect(marketplace_listing.seller_id).to be_present
      expect(marketplace_listing.status).to eq "draft"
    end
    context "passed just bike" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
      let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item: bike) }
      it "uses bike user" do
        expect(bike.user&.id).to be_present
        expect(marketplace_listing.seller_id).to eq bike.user.id
      end
    end
  end

  describe "find_or_build_current_for" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let(:user) { bike.user }

    def expect_new_marketplace_listing(passed_bike)
      marketplace_listing = MarketplaceListing.find_or_build_current_for(passed_bike)
      expect(marketplace_listing).to be_valid
      expect(marketplace_listing.status).to eq "draft"
      expect(marketplace_listing.seller_id).to eq user.id
      expect(marketplace_listing.condition).to eq "good"
      expect(marketplace_listing.amount_cents).to be_blank
      expect(marketplace_listing.id).to be_blank
      marketplace_listing
    end

    it "returns a new marketplace_listing" do
      expect(bike.reload.current_ownership.user_id).to eq user.id
      marketplace_listing = expect_new_marketplace_listing(bike)
      expect(marketplace_listing.address_record_id).to be_blank
    end

    context "with user with address record" do
      let!(:address_record) { FactoryBot.create(:address_record, user:) }
      before { user.update(address_record:) }

      it "returns with address_record_id" do
        expect(user.reload.address_record_id).to eq address_record.id
        marketplace_listing = expect_new_marketplace_listing(bike)
        expect(marketplace_listing.address_record_id).to eq address_record.id
      end
    end

    context "with marketplace_listing" do
      let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item: bike, seller: user, status:) }
      let(:status) { "for_sale" }

      it "returns the current" do
        expect(bike.reload.marketplace_listings.pluck(:id)).to eq([marketplace_listing.id])
        expect(bike.reload.marketplace_listings.current.pluck(:id)).to eq([marketplace_listing.id])
        expect(MarketplaceListing.find_or_build_current_for(bike).id).to eq marketplace_listing.id
      end

      context "with status: removed" do
        let(:status) { "removed" }

        it "returns a new marketplace listing" do
          expect(bike.reload.marketplace_listings.pluck(:id)).to eq([marketplace_listing.id])
          expect(bike.reload.marketplace_listings.current.pluck(:id)).to eq([])
          expect_new_marketplace_listing(bike)
        end
      end
    end
  end

  describe "condition_humanized" do
    it "returns correct condition" do
      expect(MarketplaceListing.condition_humanized("new_in_box")).to eq "new"
      expect(MarketplaceListing.condition_description_humanized("new_in_box")).to eq "unridden/with tags"
      expect(MarketplaceListing.condition_with_description_humanized("new_in_box")).to eq "new - unridden/with tags"
    end

    it "has values for all conditions" do
      MarketplaceListing.conditions.keys.each do |condition|
        expect(MarketplaceListing.condition_humanized(condition)).to be_present
        expect(MarketplaceListing.condition_description_humanized(condition)).to be_present
        expect(MarketplaceListing.condition_with_description_humanized(condition)).to be_present
      end
    end
  end

  describe "permitted_update" do
    let(:user) { FactoryBot.create(:superuser) }
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:) }
    let(:params) { ActionController::Parameters.new(nested_params) }
    let!(:current_ownership) { bike.reload.current_ownership }
    let(:address_record) { nil }
    let(:default_address_record_attrs) do
      {
        country_id: Country.canada_id.to_s,
        city: "Edmonton",
        region_record_id: "",
        region_string: "AB",
        postal_code: "AB T6G 2B3",
        user_account_address: "0",
        id: address_record&.id
      }
    end
    let(:address_record_attributes) { default_address_record_attrs }

    let(:nested_params) do
      {
        bike: {
          current_marketplace_listing_attributes: {
            condition: "good",
            amount_with_nil: "300.69",
            address_record_attributes:
          }
        }
      }
    end
    let(:target_address_attrs) do
      default_address_record_attrs.except(:id)
        .merge(user_id: user.id, kind: :marketplace_listing, publicly_visible_attribute: :postal_code)
    end

    def update_with_bike_updator(user:, bike:, current_ownership:, params:, marketplace_listing_change: 1, address_record_change: 1)
      Sidekiq::Job.clear_all

      expect do
        BikeUpdator.new(user:, bike:, params:, current_ownership:).update_available_attributes
      end.to change(MarketplaceListing, :count).by(marketplace_listing_change)
        .and change(AddressRecord, :count).by address_record_change

      # Required to set the correct attributes on created address record
      Callbacks::AddressRecordUpdateAssociationsJob.drain

      bike.reload
    end

    it "permits the expected active controller params" do
      update_with_bike_updator(user:, bike:, params:, current_ownership:)

      expect(bike.current_marketplace_listing).to be_present
      marketplace_listing = bike.current_marketplace_listing
      expect(marketplace_listing.amount_cents).to eq 30069
      expect(marketplace_listing.condition).to eq "good"

      expect(marketplace_listing.address_record_id).to be_present
      expect(marketplace_listing.address_record).to match_hash_indifferently target_address_attrs
    end

    # MARKETPLACE_FREE_UNTIL
    # context "user can not create listings" do
    #   let(:user) { FactoryBot.create(:user_confirmed) }

    #   it "updates the marketplace_listing (not creating)" do
    #     expect(user.reload.can_create_listing?).to be_falsey
    #     update_with_bike_updator(user:, bike:, params:, current_ownership:, marketplace_listing_change: 0, address_record_change: 0)
    #     expect(bike.current_marketplace_listing&.id).to be_blank
    #   end
    # end

    context "existing user_account_address" do
      let!(:address_record) { FactoryBot.create(:address_record, user:, kind: :user) }
      before do
        Callbacks::AddressRecordUpdateAssociationsJob.new.perform(address_record.id)
        expect(user.reload.address_record_id).to be_present
      end

      it "permits the expected active controller params" do
        update_with_bike_updator(user:, bike:, params:, current_ownership:)

        expect(bike.current_marketplace_listing).to be_present
        marketplace_listing = bike.current_marketplace_listing
        expect(marketplace_listing.amount_cents).to eq 30069
        expect(marketplace_listing.condition).to eq "good"

        expect(marketplace_listing.address_record_id).to be_present
        expect(marketplace_listing.address_record).to match_hash_indifferently target_address_attrs
      end

      context "with user_account_address: true" do
        let(:address_record_attributes) { default_address_record_attrs.merge(user_account_address: "1") }

        it "uses the address_record" do
          bike.reload
          update_with_bike_updator(user:, bike:, params:, current_ownership:, address_record_change: 0)
          expect(bike.current_marketplace_listing).to be_present
          marketplace_listing = bike.current_marketplace_listing
          expect(marketplace_listing.amount_cents).to eq 30069
          expect(marketplace_listing.condition).to eq "good"

          expect(marketplace_listing.address_record_id).to eq address_record.id
          expect(address_record.reload.kind).to eq "user"
        end
      end
    end

    context "with existing marketplace_listing" do
      let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item: bike, seller: bike.user, condition: :new_in_box, amount_cents: nil) }

      it "doesn't create a new marketplace_listing" do
        expect(bike.reload.current_marketplace_listing&.id).to eq marketplace_listing.id

        update_with_bike_updator(user:, bike:, params:, current_ownership:, marketplace_listing_change: 0)
        expect(bike.current_marketplace_listing.id).to eq marketplace_listing.id
        expect(marketplace_listing.reload.amount_cents).to eq 30069
        expect(marketplace_listing.condition).to eq "good"

        # Updating without passing current_marketplace_listing_attributes doesn't remove the listing
        BikeUpdator.new(user:, bike:, current_ownership:, permitted_params: {bike: {name: "New name"}}.as_json).update_available_attributes
        expect(bike.reload.name).to eq "New name"
        expect(bike.reload.current_marketplace_listing&.id).to eq marketplace_listing.id
      end

      # MARKETPLACE_FREE_UNTIL
      # context "user can not create listings" do
      #   let(:user) { FactoryBot.create(:user_confirmed) }

      #   it "updates the marketplace_listing (not creating)" do
      #     expect(user.reload.can_create_listing?).to be_falsey
      #     update_with_bike_updator(user:, bike:, params:, current_ownership:, marketplace_listing_change: 0)
      #     expect(bike.current_marketplace_listing.id).to eq marketplace_listing.id
      #     expect(marketplace_listing.reload.amount_cents).to eq 30069
      #     expect(marketplace_listing.condition).to eq "good"
      #   end
      # end
    end
  end

  describe "validate_publishable?" do
    let(:user_hidden) { false }
    let(:primary_activity) { FactoryBot.create(:primary_activity) }
    let(:item) { FactoryBot.create(:bike, :with_ownership_claimed, user_hidden:, cycle_type: :stroller, primary_activity:) }
    let(:user) { item.user }
    let(:address_record) { FactoryBot.create(:address_record, user:, kind: :user) }
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item:, address_record:, condition: "poor") }

    it "is truthy" do
      expect(marketplace_listing.validate_publishable?).to be_truthy
      expect(marketplace_listing.errors.full_messages).to eq([])
    end

    context "no price" do
      it "is false" do
        marketplace_listing.amount_cents = nil
        expect(marketplace_listing.validate_publishable?).to be_falsey
        expect(marketplace_listing.errors.full_messages).to eq(["Price is required"])
      end
    end
    context "user hidden" do
      let(:user_hidden) { true }
      it "is false when item is missing" do
        expect(item.reload.current?).to be_falsey
        expect(marketplace_listing.validate_publishable?).to be_falsey
        expect(marketplace_listing.errors.full_messages).to eq(["Stroller is not visible - maybe you marked it hidden?"])
      end
    end
  end

  describe "visible_by?" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing) }
    it "is visible by the user" do
      expect(marketplace_listing.visible_by?).to be_falsey
      expect(marketplace_listing.visible_by?(marketplace_listing.seller)).to be_truthy
    end
  end
end
