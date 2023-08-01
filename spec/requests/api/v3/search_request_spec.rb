require "rails_helper"

RSpec.describe "Search API V3", type: :request do
  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:color) { FactoryBot.create(:color) }
  describe "/" do
    let!(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer) }
    let!(:bike2) { FactoryBot.create(:stolen_bike, manufacturer: manufacturer) }
    let(:query_params) { {query_items: [manufacturer.search_id]} }
    context "with per_page" do
      it "returns matching bikes, defaults to stolen" do
        expect(Bike.count).to eq 2
        get "/api/v3/search", params: query_params.merge(per_page: 1, format: :json)
        expect(response.header["Total"]).to eq("1")
        result = JSON.parse(response.body)
        expect(result["bikes"][0]["id"]).to eq bike2.id
        expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
        expect(response.headers["Access-Control-Request-Method"]).to eq("*")
      end
    end
    context "cycle_type" do
      let(:query_params) { {query_items: ["v_8"], stolenness: "all", format: :json} }
      let!(:bike2) { FactoryBot.create(:bike, manufacturer: manufacturer, cycle_type: :cargo) }
      it "returns matching bikes" do
        expect(Bike.count).to eq 2
        expect(Bike.where(cycle_type: "cargo").count).to eq 1
        get "/api/v3/search", params: query_params
        expect(response.header["Total"]).to eq("1")
        result = JSON.parse(response.body)
        expect(result["bikes"][0]["id"]).to eq bike2.id
        expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
        expect(response.headers["Access-Control-Request-Method"]).to eq("*")
        # It works with manufacturer
        get "/api/v3/search", params: query_params.merge(manufacturer: manufacturer.name)
        expect(response.header["Total"]).to eq("1")
        expect(json_result["bikes"][0]["id"]).to eq bike2.id
        # Also works passing the cycle_type
        get "/api/v3/search", params: {cycle_type: "Cargo Bike (front storage)", stolenness: "all"}
        expect(response.header["Total"]).to eq("1")
        expect(json_result["bikes"][0]["id"]).to eq bike2.id
      end
    end
  end

  describe "/close_serials" do
    let!(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer, serial_number: "something") }
    let(:query_params) { {serial: "somethind", stolenness: "non"} }
    let(:target_interpreted_params) { Bike.searchable_interpreted_params(query_params, ip: nil) }
    context "with per_page" do
      it "returns matching bikes, defaults to stolen" do
        get "/api/v3/search/close_serials", params: query_params.merge(format: :json)
        result = JSON.parse(response.body)
        expect(result["bikes"][0]["id"]).to eq bike.id
        expect(response.header["Total"]).to eq("1")
      end
    end
  end

  describe "/serials_containing" do
    let!(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer, serial_number: "serial_number") }
    it "returns matching bikes with serials containing the string" do
      get "/api/v3/search/serials_containing", params: {serial: "serial_num", stolenness: "non", format: :json}
      expect(json_result[:bikes]).to be_present
      expect(json_result[:bikes].map { |b| b["id"] }).to eq([bike.id])
      expect(response.header["Total"]).to eq("1")
      # It finds without spaces
      get "/api/v3/search/serials_containing", params: {serial: "serialnum", stolenness: "non", format: :json}
      expect(json_result[:bikes]).to be_present
      expect(json_result[:bikes].map { |b| b["id"] }).to eq([bike.id])
      # It finds with extra spaces
      get "/api/v3/search/serials_containing", params: {serial: "s-e-r-ia\nln\num", stolenness: "non", format: :json}
      expect(json_result[:bikes]).to be_present
      expect(json_result[:bikes].map { |b| b["id"] }).to eq([bike.id])
      expect(response.header["Total"]).to eq "1"
    end
  end

  describe "/external_registries" do
    context "returns bikes" do
      it "returns matching bikes" do
        serial_number = "38224"
        FactoryBot.create(:external_registry_bike, serial_number: serial_number)

        allow(ExternalRegistryClient).to(receive(:search_for_bikes_with)
          .with(serial_number).and_return(ExternalRegistryBike.all))

        get "/api/v3/search/external_registries", params: {serial: serial_number, format: :json}

        expect(json_result[:error]).to be_blank
        bike_list = json_result[:bikes]
        expect(bike_list.count).to eq(1)
        expect(bike_list.first.keys)
          .to(match_array(%w[
            date_stolen
            description
            external_id
            frame_colors
            frame_model
            id
            is_stock_img
            large_img
            location_found
            manufacturer_name
            registry_name
            registry_url
            serial
            status
            stolen
            stolen_coordinates
            stolen_location
            thumb
            title
            url
            year
          ]))
        expect(response.header["Total"]).to eq("1")
      end
    end
  end

  describe "/count" do
    context "incorrect stolenness value" do
      it "returns an error message" do
        get "/api/v3/search/count", params: {stolenness: "something else", format: :json}
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
          colors: color.slug.to_s,
          location: "Chicago, IL",
          distance: 20,
          stolenness: "stolen"
        }
      end
      let(:proximity_query_params) { request_query_params.merge(stolenness: "proximity") }
      let(:proximity_interpreted_params) { Bike.searchable_interpreted_params(proximity_query_params, ip: "") }
      # Use the interpreted params, because they come with proximity data - it"s what we do in the API
      let(:stolen_interpreted_params) { proximity_interpreted_params.merge(stolenness: "stolen") }
      let(:non_stolen_interpreted_params) { proximity_interpreted_params.merge(stolenness: "non") }
      let!(:non_stolen) { FactoryBot.create(:bike, manufacturer: manufacturer, primary_frame_color: color, serial_number: "s") }
      let!(:stolen) { FactoryBot.create(:stolen_bike, manufacturer: manufacturer, primary_frame_color: color, serial_number: "5") }
      let!(:stolen_proximity) { FactoryBot.create(:stolen_bike_in_chicago, manufacturer: manufacturer, secondary_frame_color: color, serial_number: "S") }
      include_context :geocoder_real
      it "calls Bike Search with the expected interpreted_params" do
        VCR.use_cassette("v3_bike_search-count") do
          get "/api/v3/search/count", params: request_query_params.merge(format: :json)
          result = JSON.parse(response.body)
          expect(result).to match({non: 1, stolen: 2, proximity: 1}.as_json)
          expect(response.status).to eq(200)
          expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
          expect(response.headers["Access-Control-Request-Method"]).to eq("*")
        end
      end
    end
    context "nil params" do
      it "succeeds" do
        get "/api/v3/search/count", params: {stolenness: "", query_items: [], serial: "", format: :json}
        # JSON.parse(response.body)
        expect(response.status).to eq(200)
      end
    end
    context "with query items" do
      let!(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer) }
      let!(:bike2) { FactoryBot.create(:bike) }
      let(:query_params) { {query_items: [manufacturer.search_id]} }
      it "succeeds" do
        get "/api/v3/search/count", params: query_params.merge(format: :json)
        result = JSON.parse(response.body)
        expect(result["non"]).to eq 1
        expect(response.status).to eq(200)
      end
      context "with colors" do
        let!(:color) { FactoryBot.create(:color, name: "Purple") }
        let(:target) { {non: 0, proximity: 0, stolen: 0} }
        it "succeeds" do
          get "/api/v3/search/count?colors%5B%5D=#{color.id}&stolenness=non&location=edmonton"
          expect(json_result).to eq target.as_json
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
