require "rails_helper"

RSpec.describe Search::MarketplaceController, type: :request do
  let(:base_url) { "/search/marketplace" }

  it "redirects from marketplace" do
    get "/marketplace"
    expect(response).to redirect_to base_url
    # Sanity check
    expect(search_marketplace_path).to eq base_url
  end

  context "with listings" do
    let(:seller) { FactoryBot.create(:user, :with_address_record) }
    let(:item) { FactoryBot.create(:bike, :with_primary_activity, cycle_type: "personal-mobility", propulsion_type: "throttle") }
    let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, address_record: seller.address_record, seller:, item:) }
    let!(:marketplace_listing_draft) { FactoryBot.create(:marketplace_listing, :with_address_record, status: :draft, seller:) }
    let(:address_record) { FactoryBot.create(:address_record, :new_york, kind: :marketplace_listing, user: seller) }
    let(:marketplace_listing_nyc) { FactoryBot.create(:marketplace_listing, :for_sale, seller:, address_record:) }
    describe "index" do
      it "renders" do
        get base_url
        expect(flash).to be_blank
        expect(response).to render_template("index")
        expect(assigns(:interpreted_params)).to eq(stolenness: "all")
        expect(assigns(:bikes)).to be_blank
      end

      context "with search_no_js" do
        let!(:marketplace_listing_sold) { FactoryBot.create(:marketplace_listing, :sold, seller:) }
        let!(:marketplace_listing_removed) do
          FactoryBot.create(:marketplace_listing, status: :removed, seller:, item:,
            created_at: Time.current - 1.year, published_at: Time.current - 2.months, end_at: Time.current - 1.month)
        end

        it "renders with bikes" do
          expect(marketplace_listing_removed.reload.published_at).to be < marketplace_listing_removed.end_at
          expect(MarketplaceListing.pluck(:status)).to match_array(%w[for_sale draft sold removed])
          expect(Bike.for_sale.pluck(:id)).to eq([item.id])
          get "#{base_url}?search_no_js=true"
          expect(response.code).to eq("200")
          expect(response).to render_template(:index)
          expect(assigns(:interpreted_params)).to eq(stolenness: "all")
          expect(assigns(:bikes).pluck(:id)).to eq([item.id])

          # Searching with serial doesn't render registrations with serials similar
          get "#{base_url}?search_no_js=true&serial=xxxz"
          expect(response).to render_template(:index)
          expect(assigns(:bikes).pluck(:id)).to eq([])
          expect(response.body).to match "xxxz"
          # Verify that it shows marketplace, not registrations text
          expect(response.body).to match "No listings exactly matched your search"
          # FWIW, this doesn't fail anyway - but it's a reminder, don't search similar serials on marketplace
          expect(response.body).to_not match "with serials similar"
        end
      end

      context "turbo_stream" do
        it "renders" do
          get base_url, as: :turbo_stream
          expect(response.media_type).to eq Mime[:turbo_stream].to_s
          expect(response.content_type).to include("text/vnd.turbo-stream.html")
          expect(response).to have_http_status(:success)

          expect(response.body).to include("<turbo-stream action=\"replace\" target=\"search_marketplace_results_frame\">")
          expect(response).to render_template(:index)
          expect(assigns(:interpreted_params)).to eq(stolenness: "all")
          expect(assigns(:bikes).pluck(:id)).to eq([item.id])
          # Expect there to be a link to the bike url
          expect(response.body).to match(/href="#{ENV["BASE_URL"]}\/bikes\/#{item.id}"/)
        end

        context "geocoder_stubbed_bounding_box" do
          let(:ip_address) { "23.115.69.69" }
          let(:interpreted_params_location) { {stolenness: "all", location: default_location[:formatted_address], bounding_box:, distance: 50} }
          let(:headers) { {"HTTP_CF_CONNECTING_IP" => ip_address} }
          include_context :geocoder_stubbed_bounding_box
          include_context :geocoder_default_location

          it "assigns defaults, searches by proximity" do
            expect(marketplace_listing_nyc.reload.to_coordinates).to eq default_location_coordinates
            expect(marketplace_listing_nyc.item.motorized?).to be_falsey
            expect(marketplace_listing.reload.longitude).to be_within(1).of(-121) # Davis
            expect(marketplace_listing.item.motorized?).to be_truthy

            get base_url, as: :turbo_stream
            expect(response.status).to eq 200
            expect(response).to render_template(:index)
            expect(flash).to_not be_present
            expect(assigns(:interpreted_params)).to eq(stolenness: "all")
            expect(assigns(:selected_query_items_options)).to eq([])
            expect(assigns(:bikes).map(&:id)).to match_array([item.id, marketplace_listing_nyc.item_id])
            # Test cycle_type
            get "#{base_url}?marketplace_scope=for_sale&query_items%5B%5D=v_18", as: :turbo_stream
            expect(response).to render_template(:index)
            expect(assigns(:interpreted_params)).to eq(stolenness: "all", cycle_type: :"personal-mobility")
            expect(assigns(:bikes).map(&:id)).to eq([item.id])
            # Test motorized, invalid marketplace_scope
            get "#{base_url}?marketplace_scope=not_for_sale&query_items%5B%5D=p_10", as: :turbo_stream
            expect(response).to render_template(:index)
            expect(assigns(:interpreted_params)).to eq(stolenness: "all", propulsion_type: :motorized)
            expect(assigns(:bikes).map(&:id)).to eq([item.id])
            # Test location
            get "#{base_url}?marketplace_scope=for_sale_proximity", as: :turbo_stream
            expect(response).to render_template(:index)
            expect(assigns(:interpreted_params)).to eq interpreted_params_location
            expect(assigns(:bikes).map(&:id)).to eq([marketplace_listing_nyc.item_id])
          end
        end
      end
    end

    describe "counts" do
      it "renders empty" do
        get "#{base_url}/counts"
        expect(response.status).to eq 200
        expect(json_result).to match_hash_indifferently({for_sale: 1, for_sale_proximity: 0})
      end

      context "with listings" do
        let(:seller) { FactoryBot.create(:user, :with_address_record) }
        let(:item) { FactoryBot.create(:bike, :with_primary_activity, cycle_type: "personal-mobility", propulsion_type: "throttle") }
        let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, address_record: seller.address_record, seller:, item:) }
        let!(:marketplace_listing_draft) { FactoryBot.create(:marketplace_listing, :with_address_record, status: :draft, seller:) }
        let!(:address_record) { FactoryBot.create(:address_record, :new_york, kind: :marketplace_listing, user: seller) }
        let!(:marketplace_listing_nyc) { FactoryBot.create(:marketplace_listing, :for_sale, seller:, address_record:) }
        let(:target_result) { {for_sale: 2, for_sale_proximity: 1} }
        include_context :geocoder_real

        it "renders the counts" do
          expect(marketplace_listing_nyc.reload.to_coordinates).to eq default_location_coordinates
          expect(marketplace_listing_nyc.item.motorized?).to be_falsey
          expect(marketplace_listing.reload.longitude).to be_within(1).of(-121) # Davis

          VCR.use_cassette("search_marketplace-counts") do
            get "#{base_url}/counts?location=davis%2C+ca"
            expect(response.status).to eq 200
            expect(json_result).to match_hash_indifferently target_result

            # same result if marketplace_scope for_sale
            get "#{base_url}/counts?location=davis%2C+ca&marketplace_scope=for_sale"
            expect(response.status).to eq 200
            expect(json_result).to match_hash_indifferently target_result
            # same result if marketplace_scope for_sale_proximity
            get "#{base_url}/counts?location=davis%2C+ca&marketplace_scope=for_sale_proximity"
            expect(response.status).to eq 200
            expect(json_result).to match_hash_indifferently target_result

            # If searched for a propulsion_type, just return those matches
            get "#{base_url}/counts?location=davis%2C+ca&marketplace_scope=for_sale_proximity&query_items%5B%5D=p_10"
            expect(response.status).to eq 200
            expect(json_result).to match_hash_indifferently({for_sale: 1, for_sale_proximity: 1})
          end
        end
      end
    end
  end
end
