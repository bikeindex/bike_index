require "rails_helper"

RSpec.describe Search::RegistrationsController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/search/registrations" }
  let!(:non_stolen_bike) { FactoryBot.create(:bike, serial_number: "1234567890") }
  let!(:stolen_bike) { FactoryBot.create(:stolen_bike_in_nyc, serial_number: "345678901") }
  let!(:impounded_bike) { FactoryBot.create(:impounded_bike, :in_nyc, serial_number: "12345678901") }
  let!(:stolen_bike_2) { FactoryBot.create(:stolen_bike_in_los_angeles, cycle_type: "e-scooter", serial_number: "9876543210") }

  describe "index" do
    let(:target_bike_ids) { [stolen_bike.id, impounded_bike.id, stolen_bike_2.id] }

    it "redirects from search" do
      get "/search"
      expect(response).to redirect_to base_url
    end

    it "renders" do
      get base_url
      expect(response.code).to eq("200")
      expect(response).to render_template(:index)
      expect(assigns(:interpreted_params)).to eq(stolenness: "stolen")
      expect(assigns(:bikes)).to be_blank
    end

    context "with search_no_js" do
      it "renders with bikes" do
        get "#{base_url}?search_no_js=true"
        expect(response.code).to eq("200")
        expect(response).to render_template(:index)
        expect(assigns(:interpreted_params)).to eq(stolenness: "stolen")

        expect(assigns(:bikes).pluck(:id).sort).to eq target_bike_ids
      end
    end

    context "turbo_stream" do
      it "renders" do
        get base_url, as: :turbo_stream
        expect(response.media_type).to eq Mime[:turbo_stream].to_s
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
        expect(response).to have_http_status(:success)

        expect(response.body).to include("<turbo-stream action=\"replace\" target=\"search_registrations_results_frame\">")
        expect(response).to render_template(:index)
        expect(assigns(:interpreted_params)).to eq(stolenness: "stolen")
        expect(assigns(:bikes).pluck(:id).sort).to eq target_bike_ids
      end
    end
  end

  describe "similar_serials" do
    let(:serial) { "1234667890" }
    let(:target_params) do
      {raw_serial: "1234667890", serial: "1234667890", serial_no_space: "1234667890",
       stolenness: "stolen"}
    end

    it "renders" do
      get "#{base_url}/similar_serials?serial=#{serial}"
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:similar_serials)
      expect(assigns(:interpreted_params)).to eq target_params
      expect(assigns(:bikes).pluck(:id)).to eq([impounded_bike.id])
    end
  end

  describe "serials_containing" do
    let(:serial) { "3456789" }
    let(:target_params) do
      {raw_serial: "3456789", serial: "3456789", serial_no_space: "3456789", stolenness: "stolen"}
    end

    it "renders" do
      get "#{base_url}/serials_containing?serial=#{serial}"
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:serials_containing)
      expect(assigns(:interpreted_params)).to eq target_params
      expect(assigns(:bikes).pluck(:id).sort).to eq([stolen_bike.id, impounded_bike.id])
    end
  end
end
