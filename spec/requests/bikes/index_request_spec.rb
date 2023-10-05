require "rails_helper"

RSpec.describe "BikesController#index", type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bikes" }
  let!(:non_stolen_bike) { FactoryBot.create(:bike, serial_number: "1234567890") }
  let!(:stolen_bike) { FactoryBot.create(:stolen_bike_in_nyc) }
  let!(:impounded_bike) { FactoryBot.create(:impounded_bike, :in_nyc) }
  let(:serial) { "1234567890" }
  let!(:stolen_bike_2) { FactoryBot.create(:stolen_bike_in_los_angeles, cycle_type: "e-scooter") }

  it "renders" do
    get base_url
    expect(response.code).to eq("200")
    expect(response).to render_template(:index)
    expect(assigns(:interpreted_params)).to eq(stolenness: "stolen")
    expect(assigns(:bikes).pluck(:id)).to match_array([stolen_bike_2.id, impounded_bike.id, stolen_bike.id])
  end

  context "geocoder_stubbed_bounding_box" do
    let(:ip_address) { "23.115.69.69" }
    let(:target_location) { ["New York", "NY", "US"] }
    let(:target_interpreted_params) { Bike.searchable_interpreted_params(query_params, ip: ip_address) }
    let(:headers) { {"HTTP_CF_CONNECTING_IP" => ip_address} }
    include_context :geocoder_stubbed_bounding_box

    describe "assignment" do
      context "no params" do
        it "assigns defaults, stolenness: stolen" do
          get base_url
          expect(response.status).to eq 200
          expect(response).to render_template(:index)
          expect(flash).to_not be_present
          expect(assigns(:interpreted_params)).to eq(stolenness: "stolen")
          expect(assigns(:selected_query_items_options)).to eq([])
          expect(assigns(:bikes).map(&:id)).to match_array([stolen_bike.id, stolen_bike_2.id, impounded_bike.id])
          expect(assigns(:page_id)).to eq "bikes_index"
          # Test cycle_type
          get "#{base_url}?query_items%5B%5D=v_16"
          expect(response.status).to eq 200
          expect(response).to render_template(:index)
          expect(flash).to_not be_present
          expect(assigns(:interpreted_params)).to eq(stolenness: "stolen", cycle_type: :"e-scooter")
          expect(assigns(:bikes).map(&:id)).to eq([stolen_bike_2.id])
          # Test impounded
          get "#{base_url}?stolenness=found"
          expect(assigns(:interpreted_params)).to eq(stolenness: "found")
          expect(assigns(:selected_query_items_options)).to eq([])
          expect(assigns(:bikes).map(&:id)).to match_array([impounded_bike.id])
          get base_url, params: {stolenness: "impounded"}
          expect(assigns(:interpreted_params)).to eq(stolenness: "impounded")
          expect(assigns(:selected_query_items_options)).to eq([])
          expect(assigns(:bikes).map(&:id)).to match_array([impounded_bike.id])
        end
      end
      context "query_items and serial search" do
        let(:manufacturer) { non_stolen_bike.manufacturer }
        let(:color) { non_stolen_bike.primary_frame_color }
        let(:query_params) { {serial: "#{serial}0d", query_items: [color.search_id, manufacturer.search_id], stolenness: "non"} }
        let(:target_selected_query_items_options) { Bike.selected_query_items_options(target_interpreted_params) }
        it "assigns passed parameters, assigns close_serials" do
          get base_url, params: query_params
          expect(response.status).to eq 200
          expect(assigns(:interpreted_params)).to eq target_interpreted_params
          expect(assigns(:selected_query_items_options)).to eq target_selected_query_items_options
          expect(assigns(:bikes).map(&:id)).to eq([])
        end
      end
      context "ip proximity" do
        let(:query_params) { {location: "yoU", distance: 1, stolenness: "proximity"} }
        context "found location" do
          it "assigns passed parameters and close_serials" do
            allow(Geocoder).to receive(:search) { legacy_production_ip_search_result }
            get base_url, params: query_params, headers: headers
            expect(response.status).to eq 200
            expect(assigns(:interpreted_params)).to eq target_interpreted_params
            expect(assigns(:bikes).map(&:id)).to match_array([stolen_bike.id, impounded_bike.id])
          end
        end
        context "ip passed as parameter" do
          let(:ip_query_params) { query_params.merge(location: "IP") }
          it "assigns passed parameters and close_serials" do
            allow(Geocoder).to receive(:search) { production_ip_search_result }
            get base_url, params: ip_query_params, headers: headers
            expect(response.status).to eq 200
            expect(assigns(:interpreted_params)).to eq target_interpreted_params.merge(location: target_location)
            expect(assigns(:bikes).map(&:id)).to match_array([stolen_bike.id, impounded_bike.id])
          end
        end
        context "no location" do
          let(:ip_query_params) { query_params.merge(location: "   ") }
          it "assigns passed parameters and close_serials" do
            allow(Geocoder).to receive(:search) { production_ip_search_result }
            get base_url, params: ip_query_params, headers: headers
            expect(response.status).to eq 200
            expect(assigns(:interpreted_params)).to eq target_interpreted_params.merge(location: target_location)
            expect(assigns(:bikes).map(&:id)).to match_array([stolen_bike.id, impounded_bike.id])
          end
        end
        context "unknown location" do
          # Override bounding box stub in geocoder_default_location shared context
          let(:bounding_box) { [66.00, -84.22, 67.000, (0.0 / 0)] }
          it "includes a flash[:info] for unknown location, renders non-proximity" do
            get base_url, params: query_params, headers: headers
            expect(response.status).to eq 200
            expect(flash[:info]).to match(/location/)
            expect(query_params[:stolenness]).to eq "proximity"
            expect(assigns(:interpreted_params)[:stolenness]).to eq "stolen"
            expect(assigns(:bikes).map(&:id)).to match_array([stolen_bike.id, stolen_bike_2.id, impounded_bike.id])
          end
        end
      end
      describe "stubbing" do
        let(:query_params) do
          ActionController::Parameters.new(
            query: "1",
            manufacturer: "2",
            colors: %w[3 4],
            location: "5",
            distance: "6",
            serial: "9",
            query_items: %w[7 8],
            stolenness: "all"
          ).permit(
            :query,
            :manufacturer,
            :colors,
            :location,
            :distance,
            :serial,
            :query_items,
            :stolenness
          )
        end
        let(:ip_address) { "special" }
        it "sends all the params we want to searchable_interpreted_params" do
          expect(Bike).to receive(:searchable_interpreted_params).with(query_params, ip: "special") { {} }
          get base_url, params: query_params.to_h, headers: headers
          expect(response.status).to eq 200
        end
      end
    end
  end
end
