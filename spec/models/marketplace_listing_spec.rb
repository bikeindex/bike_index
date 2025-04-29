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
      expect(marketplace_listing.condition).to be_blank
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
      expect(MarketplaceListing.condition_humanized("new_in_box")).to eq "new in box"
    end

    it "has values for all conditions" do
      MarketplaceListing.conditions.keys.each do |condition|
        expect(MarketplaceListing.condition_humanized(condition)).to be_present
      end
    end
  end

  describe "permitted_update" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let!(:user) { bike.reload.user }
    let(:params) { ActionController::Parameters.new(nested_params) }
    let!(:current_ownership) { bike.current_ownership }
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
            condition:"fair",
            amount: "300.69",
            address_record_attributes:
          }
        }
      }
    end
    let(:b_params) { {bike: params.require(:bike).permit(BikeCreator.old_attr_accessible)}.as_json }
    let(:target_address_attrs) { default_address_record_attrs.merge(user_id: user.id, kind: :marketplace_listing, publicly_visible_attribute: :postal_code) }

    shared_examples_for 'user_account_address: false' do
      it "permits the expected active controller params" do
        expect do
          updated_bike = BikeUpdator.new(user:, bike:, b_params:, current_ownership:).update_available_attributes
          pp updated_bike.errors.full_messages
        end.to change(MarketplaceListing, :count).by(1)
          .and change(AddressRecord, :count).by 1

        bike.reload
        expect(bike.current_marketplace_listing).to be_present
        marketplace_listing = bike.current_marketplace_listing
        expect(marketplace_listing.amount_cents).to eq 30069
        expect(marketplace_listing.condition).to eq "fair"
        expect(marketplace_listing.address_record_id).to be_present
        expect(marketplace_listing.address_record).to match_hash_indifferently target_address_attrs
      end
    end

    it_behaves_like 'user_account_address: false'

    # context "existing user_account_address" do
    #   let!(:address_record) { FactoryBot.create(:address_record, user:, kind: :user) }

    #   it_behaves_like 'user_account_address: false'

    #   context 'with user_account_address: true'
    #     it "uses the address_record" do

    #   end
    # end
  end
end
