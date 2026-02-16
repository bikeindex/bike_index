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

    it "redirects from /bikes" do
      get "/bikes"
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
        expect(assigns(:result_view)).to eq :bike_box

        expect(assigns(:bikes).pluck(:id).sort).to eq target_bike_ids
      end
    end

    context "with stolenness: for_sale" do
      it "redirects to marketplace" do
        get "#{base_url}?search_no_js=true&stolenness=for_sale&location=Chicago%2C+IL"
        expect(response).to redirect_to("/search/marketplace?location=Chicago%2C+IL&search_no_js=true")
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
        # Expect there to be a link to the bike url
        expect(response.body).to match(/href="#{ENV["BASE_URL"]}\/bikes\/#{target_bike_ids.first}"/)
      end

      context "geocoder_stubbed_bounding_box" do
        let(:serial) { "1234567890" }
        let(:ip_address) { "23.115.69.69" }
        let(:target_location) { default_location[:formatted_address] }
        let(:target_interpreted_params) { BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address) }
        let(:headers) { {"HTTP_CF_CONNECTING_IP" => ip_address} }
        include_context :geocoder_stubbed_bounding_box
        include_context :geocoder_default_location

        describe "assignment" do
          it "assigns defaults, stolenness: stolen" do
            get base_url, as: :turbo_stream
            expect(response.status).to eq 200
            expect(response).to render_template(:index)
            expect(flash).to_not be_present
            expect(assigns(:interpreted_params)).to eq(stolenness: "stolen")
            expect(assigns(:bikes).map(&:id)).to match_array([stolen_bike.id, stolen_bike_2.id, impounded_bike.id])
            # Test cycle_type
            get "#{base_url}?query_items%5B%5D=v_16", as: :turbo_stream
            expect(response.status).to eq 200
            expect(response).to render_template(:index)
            expect(flash).to_not be_present
            expect(assigns(:interpreted_params)).to eq(stolenness: "stolen", cycle_type: :"e-scooter")
            expect(assigns(:bikes).map(&:id)).to eq([stolen_bike_2.id])
            # Test impounded
            get "#{base_url}?stolenness=found", as: :turbo_stream
            expect(assigns(:interpreted_params)).to eq(stolenness: "found")
            expect(assigns(:bikes).map(&:id)).to match_array([impounded_bike.id])
            get base_url, params: {stolenness: "impounded"}, as: :turbo_stream
            expect(assigns(:interpreted_params)).to eq(stolenness: "impounded")
            expect(assigns(:bikes).map(&:id)).to match_array([impounded_bike.id])
          end
          context "query_items and serial search" do
            let(:manufacturer) { non_stolen_bike.manufacturer }
            let(:color) { non_stolen_bike.primary_frame_color }
            let(:query_params) { {serial: "#{serial}0d", query_items: [color.search_id, manufacturer.search_id], stolenness: "non"} }
            it "assigns passed parameters, assigns close_serials" do
              get base_url, params: query_params, as: :turbo_stream
              expect(response.status).to eq 200
              expect(assigns(:interpreted_params)).to eq target_interpreted_params
              expect(assigns(:bikes).map(&:id)).to eq([])
            end
          end
          context "invalid page params" do
            it "redirects out-of-range pages to last valid page" do
              # Only 4 bikes exist, so page 100 is out of range
              get base_url, params: {page: 100}, as: :turbo_stream
              expect(response).to redirect_to("#{base_url}?page=1")
              # over MAX_PAGE - permitted_page caps to 100, still out of range
              get base_url, params: {page: 101}, as: :turbo_stream
              expect(response).to redirect_to("#{base_url}?page=1")
              # blank defaults to page 1, which is valid
              get base_url, params: {page: ""}, as: :turbo_stream
              expect(response.status).to eq 200
              expect(assigns(:page)).to eq 1
              expect(assigns(:interpreted_params)).to eq({stolenness: "stolen"})
            end
          end
          context "ip proximity" do
            let(:query_params) { {location: "yoU", distance: 1, stolenness: "proximity"} }
            context "found location" do
              it "assigns passed parameters and close_serials" do
                get base_url, params: query_params, headers: headers, as: :turbo_stream
                expect(response.status).to eq 200
                expect(assigns(:interpreted_params)).to eq target_interpreted_params
                expect(assigns(:bikes).map(&:id)).to match_array([stolen_bike.id, impounded_bike.id])
                expect(flash[:info]).to be_blank

                # with below minimum distance
                get base_url, params: query_params.merge(distance: 0.01), headers: headers, as: :turbo_stream
                expect(response.status).to eq 200
                expect(assigns(:interpreted_params)).to eq target_interpreted_params
                expect(assigns(:bikes).map(&:id)).to match_array([stolen_bike.id, impounded_bike.id])
                expect(flash[:info]).to be_blank
              end
            end
            context "ip passed as parameter" do
              let(:ip_query_params) { query_params.merge(location: "IP") }
              it "assigns passed parameters and close_serials" do
                get base_url, params: ip_query_params, headers: headers, as: :turbo_stream
                expect(response.status).to eq 200
                expect(assigns(:interpreted_params)).to eq target_interpreted_params.merge(location: target_location)
                expect(assigns(:bikes).map(&:id)).to match_array([stolen_bike.id, impounded_bike.id])
                expect(flash[:info]).to be_blank
              end
            end
            context "no location" do
              let(:ip_query_params) { query_params.merge(location: "   ") }
              it "assigns passed parameters and close_serials" do
                get base_url, params: ip_query_params, headers: headers, as: :turbo_stream
                expect(response.status).to eq 200
                expect(assigns(:interpreted_params)).to eq target_interpreted_params.merge(location: target_location)
                expect(assigns(:bikes).map(&:id)).to match_array([stolen_bike.id, impounded_bike.id])
                expect(flash[:info]).to be_blank
              end
            end
            context "unknown location" do
              # Override bounding box stub in geocoder_default_location shared context
              let(:bounding_box) { [66.00, -84.22, 67.000, (0.0 / 0)] }
              it "includes a flash[:info] for unknown location, renders non-proximity" do
                get base_url, params: query_params, headers: headers, as: :turbo_stream
                expect(response.status).to eq 200
                expect(flash[:info]).to match(/location/)
                expect(query_params[:stolenness]).to eq "proximity"
                expect(assigns(:interpreted_params)[:stolenness]).to eq "stolen"
                expect(assigns(:bikes).map(&:id)).to match_array([stolen_bike.id, stolen_bike_2.id, impounded_bike.id])
                # flash is rendered in turbo_stream response
                expect(response.body).to include("primary-alert-block")
                expect(response.body).to match(/we don&#39;t know the location/)
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
              expect(BikeSearchable).to receive(:searchable_interpreted_params).with(query_params, ip: "special") { {} }
              get base_url, params: query_params.to_h, headers: headers, as: :turbo_stream
              expect(response.status).to eq 200
            end
          end
        end
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
