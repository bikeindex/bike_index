require "rails_helper"

RSpec.describe "Search API V3", type: :request do
  before(:all) do
    ::ExternalRegistry.create_all
  end

  after(:all) do
    ::ExternalRegistry.destroy_all
  end

  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:color) { FactoryBot.create(:color) }
  describe "/" do
    let!(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer) }
    let!(:bike_2) { FactoryBot.create(:stolen_bike, manufacturer: manufacturer) }
    let(:query_params) { { query_items: [manufacturer.search_id] } }
    context "with per_page" do
      it "returns matching bikes, defaults to stolen" do
        expect(Bike.count).to eq 2
        get "/api/v3/search", query_params.merge(per_page: 1), format: :json
        expect(response.header["Total"]).to eq("1")
        result = JSON.parse(response.body)
        expect(result["bikes"][0]["id"]).to eq bike_2.id
      end
    end
  end
  describe "/close_serials" do
    let!(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer, serial_number: "something") }
    let(:query_params) { { serial: "somethind", stolenness: "non" } }
    let(:target_interpreted_params) { Bike.searchable_interpreted_params(query_params, ip: nil) }
    context "with per_page" do
      it "returns matching bikes, defaults to stolen" do
        get "/api/v3/search/close_serials", query_params, format: :json
        result = JSON.parse(response.body)
        expect(result["bikes"][0]["id"]).to eq bike.id
        expect(response.header["Total"]).to eq("1")
      end
    end
  end
  describe "/external_registries" do
    context "returns bikes" do
      it "returns matching bikes" do
        serial_number = "38224"
        FactoryBot.create(:external_registry_bike, serial_number: serial_number)

        allow(ExternalRegistry).to(receive(:search_for_bikes_with)
          .with(serial_number: serial_number).and_return(ExternalRegistryBike.all))

        get "/api/v3/search/external_registries",
            serial: serial_number,
            format: :json

        expect(json_result[:error]).to be_blank
        bike_list = json_result[:bikes]
        expect(bike_list.count).to eq(1)
        expect(bike_list.first.keys)
          .to(match_array(%w[
            id title serial manufacturer_name frame_model frame_colors
            thumb large_img is_stock_img stolen stolen_location date_stolen
            info_hash location_found external_id registry_name registry_url
            source_name source_unique_id status url description
            date_stolen_string year
          ]))
        expect(response.header["Total"]).to eq("1")
      end
    end
  end

  describe "/count" do
    context "incorrect stolenness value" do
      it "returns an error message" do
        get "/api/v3/search/count", stolenness: "something else", format: :json
        result = JSON.parse(response.body)
        expect(result["error"]).to match(/stolenness/i)
        expect(response.status).to eq(400)
      end
    end
    context "correct params" do
      let(:request_query_params) do
        {
          serial: "s",
          manufacturer: manufacturer.id,
          color_ids: [color.id],
          location: "Chicago, IL",
          distance: 20,
          stolenness: "stolen",
        }
      end
      let(:proximity_query_params) { request_query_params.merge(stolenness: "proximity") }
      let(:proximity_interpreted_params) { Bike.searchable_interpreted_params(proximity_query_params, ip: "") }
      # Use the interpreted params, because they come with proximity data - it"s what we do in the API
      let(:stolen_interpreted_params) { proximity_interpreted_params.merge(stolenness: "stolen") }
      let(:non_stolen_interpreted_params) { proximity_interpreted_params.merge(stolenness: "non") }
      let!(:non_stolen) { FactoryBot.create(:bike, manufacturer: manufacturer, primary_frame_color: color, serial_number: "s") }
      let!(:stolen) { FactoryBot.create(:stolen_bike, manufacturer: manufacturer, primary_frame_color: color, serial_number: "5") }
      let!(:stolen_proximity) { FactoryBot.create(:stolen_bike, manufacturer: manufacturer, secondary_frame_color: color, serial_number: "S", latitude: 41.8624488, longitude: -87.6591502) }
      include_context :geocoder_real
      it "calls Bike Search with the expected interpreted_params" do
        VCR.use_cassette("v3_bike_search-count") do
          get "/api/v3/search/count", request_query_params, format: :json
          result = JSON.parse(response.body)
          expect(result).to match({ non: 1, stolen: 2, proximity: 1 }.as_json)
          expect(response.status).to eq(200)
        end
      end
    end
    context "nil params" do
      it "succeeds" do
        get "/api/v3/search/count", { stolenness: "", query_items: [], serial: "" }, format: :json
        # JSON.parse(response.body)
        expect(response.status).to eq(200)
      end
    end
    context "with query items" do
      let!(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer) }
      let!(:bike_2) { FactoryBot.create(:bike) }
      let(:query_params) { { query_items: [manufacturer.search_id] } }
      it "succeeds" do
        get "/api/v3/search/count", query_params, format: :json
        result = JSON.parse(response.body)
        expect(result["non"]).to eq 1
        expect(response.status).to eq(200)
      end
    end
  end
end
