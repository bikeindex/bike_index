require "rails_helper"

RSpec.describe MyAccounts::MarketplaceListingsController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present

  describe "update" do
    let(:user) do
      FactoryBot.create(:user_confirmed, :with_address_record, address_set_manually: true)
    end
    let(:address_record) { nil }
    let(:current_user) { user }
    let!(:membership) { FactoryBot.create(:membership, user: user) }
    let!(:primary_activity_id) { FactoryBot.create(:primary_activity).id }
    let(:state) { FactoryBot.create(:state_california) }
    let(:default_address_record_attributes) do
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
    let(:address_record_attributes) { default_address_record_attributes }
    let(:marketplace_listing_params) do
      {
        condition: "good",
        amount_with_nil: "300.69",
        description: "some description",
        status: "draft",
        price_negotiable: "1",
        address_record_attributes:
      }
    end
    let(:target_marketplace_attrs) do
      marketplace_listing_params.except(:amount_with_nil, :address_record_attributes, :primary_activity_id)
        .merge(amount_cents: 30069, price_negotiable: true)
    end

    context "item: bike" do
      let(:update_url) { "/my_account/marketplace_listings/b#{bike.id}" }
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:) }
      let!(:ownership) { FactoryBot.create(:ownership_claimed, creator: user, owner_email: user.email) }
      let(:params) { {marketplace_listing: marketplace_listing_params} }
      let(:target_address_attrs) do
        address_record_attributes.except(:id, :user_account_address, :region_record_id)
          .merge(user_id: user.id, kind: "marketplace_listing", publicly_visible_attribute: "postal_code",
            country_id: Country.canada_id, region_record_id: nil)
      end

      def make_update_bike_request(url:, params:, marketplace_listing_change: 1, address_record_change: 1)
        Sidekiq::Job.clear_all
        Sidekiq::Testing.inline! do
          expect do
            patch update_url, params:
          end.to change(MarketplaceListing, :count).by(marketplace_listing_change)
            .and change(AddressRecord, :count).by(address_record_change)
        end
      end

      it "creates a new marketplace_listing and address_record" do
        expect(current_user.reload.can_create_listing?).to be_truthy
        expect(current_user.address_record_id).to be_present
        expect(bike.reload.current_marketplace_listing).to be_blank
        expect(BikeServices::CalculateLocation.registration_address_source(bike)).to eq "user"
        expect(bike.authorized?(current_user)).to be_truthy

        make_update_bike_request(url: update_url, params:)
        expect(flash[:success]).to be_present

        expect(bike.reload.current_marketplace_listing).to be_present
        expect(BikeServices::CalculateLocation.registration_address_source(bike)).to eq "user"

        marketplace_listing = bike.current_marketplace_listing
        expect(marketplace_listing).to have_attributes target_marketplace_attrs
        expect(marketplace_listing.address_record_id).to be_present
        expect(marketplace_listing.address_record).to have_attributes target_address_attrs
      end

      context "existing marketplace_listing" do
        let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :with_address_record, item: bike, amount_cents: 400, status:) }
        let(:status) { :draft }
        let(:address_record) { marketplace_listing.address_record }
        let(:new_status) { "draft" }
        let(:params) do
          {marketplace_listing: marketplace_listing_params
            .merge(id: marketplace_listing.id, amount_with_nil: "", status: new_status)}
        end

        it "updates existing marketplace_listing and address_record" do
          expect(marketplace_listing.reload.seller_id).to eq user.id
          expect(marketplace_listing.address_record).to have_attributes(user_id: user.id,
            kind: "marketplace_listing", country_id: Country.united_states_id)
          expect(marketplace_listing.address_record_id).to_not eq user.address_record_id

          make_update_bike_request(url: update_url, params:, marketplace_listing_change: 0, address_record_change: 0)
          expect(flash[:success]).to be_present

          expect(bike.reload.current_marketplace_listing&.id).to eq marketplace_listing.id
          expect(marketplace_listing.reload).to have_attributes target_marketplace_attrs.merge(amount_cents: nil)
          expect(marketplace_listing.address_record).to have_attributes target_address_attrs.merge(id: address_record.id)
        end

        context "current_user: superuser" do
          let(:address_record_attributes) { default_address_record_attributes.merge(user_account_address: "1") }
          let(:current_user) { FactoryBot.create(:superuser, :with_address_record, address_set_manually: true) }

          it "updates the listing and doesn't create an address_record" do
            expect(marketplace_listing.reload.item_id).to eq bike.id
            bike.update(primary_activity_id:)
            expect(bike.reload.current_marketplace_listing&.id).to eq marketplace_listing.id
            expect(bike.primary_activity_id).to eq primary_activity_id
            make_update_bike_request(url: update_url, params: params.merge(primary_activity_id: nil), marketplace_listing_change: 0, address_record_change: 0)
            expect(flash[:success]).to be_present

            expect(bike.reload.primary_activity_id).to eq primary_activity_id
            expect(bike.current_marketplace_listing&.id).to eq marketplace_listing.id
            expect(marketplace_listing.reload).to have_attributes target_marketplace_attrs.merge(amount_cents: nil)
            expect(marketplace_listing.address_record_id).to eq user.address_record_id
            # Sanity check - verify that it hasn't been set to the passed parameters
            expect(marketplace_listing.address_record.country_id).to eq Country.united_states_id
            expect(marketplace_listing.address_record.city).to_not eq address_record_attributes[:city]
            expect(marketplace_listing.to_coordinates).to eq([default_location[:latitude], default_location[:longitude]])
          end
        end

        context "address_record is not user's, invalid status" do
          let!(:address_record) { FactoryBot.create(:address_record, kind: :marketplace_listing, user: FactoryBot.create(:user)) }

          it "creates a new marketplace_listing and address_record" do
            expect(marketplace_listing.reload.seller_id).to eq user.id
            og_marketplace_address_record_id = marketplace_listing.address_record_id
            expect(marketplace_listing.address_record).to have_attributes(user_id: user.id,
              kind: "marketplace_listing", country_id: Country.united_states_id)
            expect(marketplace_listing.address_record_id).to_not eq user.address_record_id

            make_update_bike_request(url: update_url, params: params.merge(status: "removed"),
              marketplace_listing_change: 0, address_record_change: 0)
            expect(flash[:success]).to be_present

            expect(bike.reload.current_marketplace_listing&.id).to eq marketplace_listing.id
            expect(marketplace_listing.reload).to have_attributes target_marketplace_attrs.merge(amount_cents: nil)
            expect(marketplace_listing.address_record_id).to eq og_marketplace_address_record_id
          end
        end

        context "for_sale updated with invalid setting" do
          let(:status) { :for_sale }
          let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:, primary_activity_id:) }
          let(:new_status) { "for_sale" }
          let(:actual_updated_attrs) { target_marketplace_attrs.merge(amount_cents: nil, status: "draft") }

          it "re-renders" do
            expect(marketplace_listing.reload.seller_id).to eq user.id
            expect(marketplace_listing.status).to eq "for_sale"
            expect(marketplace_listing.valid_publishable?).to be_truthy

            make_update_bike_request(url: update_url, params:, marketplace_listing_change: 0, address_record_change: 0)

            expect(marketplace_listing.reload).to have_attributes actual_updated_attrs
            expect(flash[:error]).to be_present
            # sanity check, to make absolutely sure
            expect(marketplace_listing.status).to eq "draft"
          end
        end
      end

      context "with geocoder" do
        let(:marketplace_listing_params) do
          {
            primary_activity_id:,
            condition: "new_in_box",
            amount_with_nil: "1442.42",
            description: "other description",
            price_negotiable: "0",
            address_record_attributes:
          }
        end
        let(:address_record_attributes) do
          {
            country_id: Country.united_states_id.to_s,
            city: "Los Angeles",
            region_record_id: state.id,
            region_string: "Fake Region",
            postal_code: "90021",
            user_account_address: "false",
            id: user.address_record_id
          }
        end
        let(:target_address_attrs) do
          address_record_attributes.except(:region_string, :id, :user_account_address).merge(kind: "marketplace_listing",
            latitude: 34.0309258,
            longitude: -118.2380432,
            publicly_visible_attribute: "postal_code",
            country_id: Country.united_states_id)
        end
        let(:non_negotiable_attrs) { target_marketplace_attrs.merge(amount_cents: 144242, price_negotiable: false) }
        include_context :geocoder_real

        it "creates the listing" do
          expect(current_user.reload.can_create_listing?).to be_truthy
          expect(current_user.address_record_id).to be_present
          og_user_address_record_id = current_user.address_record_id
          bike.update(updated_at: Time.current, created_at: Time.current - 1.day)

          expect(bike.reload.primary_activity_id).to be_nil
          expect(bike.updated_by_user_at).to be_within(1).of bike.created_at
          # expect(bike.not_updated_by_user?).to be_truthy
          expect(bike.current_ownership.claimed?).to be_truthy
          expect(bike.to_coordinates).to eq([default_location[:latitude], default_location[:longitude]])
          expect(BikeServices::CalculateLocation.registration_address_source(bike)).to eq "user"

          VCR.use_cassette("marketplace_listing_request-update") do
            make_update_bike_request(url: update_url, params:)
          end
          expect(flash[:success]).to be_present

          marketplace_listing = bike.current_marketplace_listing
          expect(marketplace_listing).to be_present
          expect(marketplace_listing).to have_attributes non_negotiable_attrs
          expect(marketplace_listing.address_record_id).to_not eq og_user_address_record_id
          expect(marketplace_listing.address_record).to have_attributes target_address_attrs
          expect(current_user.reload.address_record_id).to eq og_user_address_record_id

          expect(bike.reload.primary_activity_id).to eq primary_activity_id
          expect(bike.to_coordinates).to eq([default_location[:latitude], default_location[:longitude]])
          expect(BikeServices::CalculateLocation.registration_address_source(bike)).to eq "user"
          expect(AddressRecord.where(user_id: current_user.id).count).to eq 2
        end
      end
      context "publishing (status: for_sale)" do
        let(:address_record_attributes) { default_address_record_attributes.merge(user_account_address: "1") }
        let(:marketplace_listing_params) do
          {
            primary_activity_id:,
            condition: "poor",
            amount_with_nil: "69.69",
            description: "Cool description",
            status: "for_sale",
            price_negotiable: "0",
            address_record_attributes:
          }
        end
        let(:target_for_sale_attrs) do
          target_marketplace_attrs.merge(status: "for_sale",
            amount_cents: 6969, price_negotiable: false, address_record_id: user.address_record_id)
        end
        it "updates and publishes" do
          expect(user.reload.can_create_listing?).to be_truthy
          expect(user.address_record_id).to be_present
          expect(bike.reload.current_marketplace_listing).to be_blank
          expect(BikeServices::CalculateLocation.registration_address_source(bike)).to eq "user"

          make_update_bike_request(url: update_url, params:, address_record_change: 0)

          expect(flash[:success]).to match "published"
          marketplace_listing = bike.reload.current_marketplace_listing
          expect(marketplace_listing).to be_present
          expect(marketplace_listing.valid_publishable?).to be_truthy
          expect(marketplace_listing).to have_attributes target_for_sale_attrs

          expect(BikeServices::CalculateLocation.registration_address_source(bike)).to eq "marketplace_listing"
          expect(bike.to_coordinates).to eq user.to_coordinates
        end
        context "bike is user_hidden" do
          before { bike.update(user_hidden: true) }
          it "doesn't publish" do
            make_update_bike_request(url: update_url, params:, address_record_change: 0)

            expect(flash[:error]).to match "hidden"
            expect(bike.reload.current_marketplace_listing.reload).to have_attributes target_for_sale_attrs.merge(status: "draft")
          end
        end
        context "bike is stolen" do
          let!(:stolen_record) { FactoryBot.create(:stolen_record, bike:) }
          it "doesn't publish" do
            make_update_bike_request(url: update_url, params:, address_record_change: 0)

            expect(flash[:error]).to match "stolen"
            expect(bike.reload.current_marketplace_listing.reload).to have_attributes target_for_sale_attrs.merge(status: "draft")
          end
        end
      end
      context "user can't publish listing" do
        # TODO: update when MARKETPLACE_FREE_UNTIL changes
        # let(:membership) { expired membership }
        # it "updates the marketplace_listing (not creating)" do
        #   expect(user.reload.can_create_listing?).to be_falsey
        #   update_with_bike_updator(user:, bike:, params:, current_ownership:, marketplace_listing_change: 0)
        #   expect(bike.current_marketplace_listing.id).to eq marketplace_listing.id
        #   expect(marketplace_listing.reload.amount_cents).to eq 30069
        #   expect(marketplace_listing.condition).to eq "good"
        # end
      end

      context "marketplace_listing_id not user's bike" do
        let!(:current_user) { FactoryBot.create(:user_confirmed) }

        it "doesn't update" do
          expect(current_user.reload.can_create_listing?).to be_truthy
          expect(bike.reload.authorized?(current_user)).to be_falsey

          expect do
            patch update_url, params:
          end.to_not change(MarketplaceListing, :count)

          expect(flash[:error]).to be_present
        end
      end
    end
  end
end
