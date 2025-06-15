require "rails_helper"

RSpec.describe MyAccounts::MarketplaceListingsController, type: :request do
  describe "update" do
    let(:update_url) { "/my_account/marketplace_listings/b#{bike.id}" }
    let(:address_record) { FactoryBot.create(:address_record, :new_york) }
    let(:user) { FactoryBot.create(:user_confirmed, address_set_manually: true, address_record:) }
    let(:current_user) { user }
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:) }
    let!(:membership) { FactoryBot.create(:membership, user: user) }
    let!(:ownership) { FactoryBot.create(:ownership_claimed, creator: user, owner_email: user.email) }
    let!(:primary_activity_id) { FactoryBot.create(:primary_activity).id }
    let(:state) { FactoryBot.create(:state_california) }
    let(:address_record_attributes) do
      {
        country_id: Country.united_states_id.to_s,
        city: "Los Angeles",
        region_record_id: state.id,
        region_string: "AB",
        postal_code: "90021",
        user_account_address: "false",
        id: address_record&.id
      }
    end
    let(:marketplace_listing_params) do
      {
        primary_activity_id:,
        condition: "new_in_box",
        amount_with_nil: "1442.42",
        description: "some description",
        price_negotiable: "1",
        address_record_attributes:
      }
    end
    let(:target_marketplace_attrs) do
      marketplace_listing_params.except(:amount_with_nil, :address_record_attributes, :primary_activity_id)
        .merge(amount_cents: 144242, status: "draft", price_negotiable: true)
    end
    include_context :geocoder_real
    it "creates the listing" do
      expect(user.reload.can_create_listing?).to be_truthy
      bike.update(updated_at: Time.current, created_at: Time.current - 1.day)

      expect(bike.reload.primary_activity_id).to be_nil
      expect(bike.updated_by_user_at).to be_within(1).of bike.created_at
      # expect(bike.not_updated_by_user?).to be_truthy
      expect(bike.current_ownership.claimed?).to be_truthy
      expect(bike.to_coordinates).to eq([default_location[:latitude], default_location[:longitude]])

      VCR.use_cassette("marketplace_listing_request-update") do
        Sidekiq::Job.clear_all
        Sidekiq::Testing.inline! do
          expect do
            patch update_url, params: {marketplace_listing: marketplace_listing_params}
          end.to change(MarketplaceListing, :count).by 1
        end
      end

      marketplace_listing = bike.current_marketplace_listing
      expect(marketplace_listing).to be_present
      expect(marketplace_listing).to match_hash_indifferently target_marketplace_attrs
      expect(bike.reload.primary_activity_id).to eq primary_activity_id

      address_record = marketplace_listing.address_record
      expect(address_record).to be_present
      expect(address_record.kind).to eq "marketplace_listing"
      expect(address_record.user_id).to eq user.id
      expect(address_record.region_record_id).to eq state.id
      expect(address_record.city).to eq "Los Angeles"
      expect(address_record.region_string).to be_blank
    end
    context "existing marketplace_listing" do
      let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item: bike) }
      let(:current_user) { FactoryBot.create(:superuser, :with_address_record, address_set_manually: true) }
      let(:address_record_attributes) { {user_account_address: "1"} }
      let(:existing_params) { marketplace_listing_params.merge(id: marketplace_listing.id) }

      it "updates the listing" do
        expect(bike.reload.current_marketplace_listing&.id).to eq marketplace_listing.id
        expect(marketplace_listing.reload.address_record_id).to be_blank

        VCR.use_cassette("bike_request-update-marketplace_listing") do
          Sidekiq::Job.clear_all
          Sidekiq::Testing.inline! do
            expect {
              patch update_url, params: {marketplace_listing: marketplace_listing_params}
              expect(flash[:success]).to be_present
            }.to change(MarketplaceListing, :count).by 0
          end
        end

        expect(bike.reload.primary_activity_id).to eq primary_activity_id
        expect(bike.current_marketplace_listing&.id).to eq marketplace_listing.id
        expect(marketplace_listing.reload).to match_hash_indifferently target_marketplace_attrs
        expect(marketplace_listing.address_record_id).to eq address_record.id
      end
    end
    context "publishing (status: for_sale)" do
    end
    context "bike is user_hidden" do
    end
    context "user can't publish listing" do
    end
    context "marketplace_listing_id of not user's bike" do
    end
  end
end
