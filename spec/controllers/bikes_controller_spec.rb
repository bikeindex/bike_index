require "rails_helper"

RSpec.describe BikesController, type: :controller do
  let!(:state) { FactoryBot.create(:state_illinois) }
  let!(:country) { state.country }

  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:color) { FactoryBot.create(:color, name: "black") }

  describe "index" do
    let!(:non_stolen_bike) { FactoryBot.create(:bike, serial_number: "1234567890") }
    let!(:stolen_bike) { FactoryBot.create(:stolen_bike_in_nyc) }
    let(:serial) { "1234567890" }
    let!(:stolen_bike_2) { FactoryBot.create(:stolen_bike_in_los_angeles) }
    let(:ip_address) { "127.0.0.1" }
    let(:target_location) { ["New York", "NY", "US"] }
    let(:target_interpreted_params) { Bike.searchable_interpreted_params(query_params, ip: ip_address) }
    include_context :geocoder_stubbed_bounding_box

    context "with subdomain" do
      it "redirects to no subdomain" do
        @request.host = "stolen.example.com"
        get :index
        expect(response).to redirect_to bikes_url(subdomain: false)
      end
    end
    describe "assignment" do
      context "no params" do
        it "assigns defaults, stolenness: stolen" do
          get :index
          expect(response.status).to eq 200
          expect(response).to render_template(:index)
          expect(flash).to_not be_present
          expect(assigns(:interpreted_params)).to eq(stolenness: "stolen")
          expect(assigns(:selected_query_items_options)).to eq([])
          expect(assigns(:bikes).map(&:id)).to match_array([stolen_bike.id, stolen_bike_2.id])
          expect(assigns(:page_id)).to eq "bikes_index"
        end
      end
      context "query_items and serial search" do
        let(:manufacturer) { non_stolen_bike.manufacturer }
        let(:color) { non_stolen_bike.primary_frame_color }
        let(:query_params) { { serial: "#{serial}0d", query_items: [color.search_id, manufacturer.search_id], stolenness: "non" } }
        let(:target_selected_query_items_options) { Bike.selected_query_items_options(target_interpreted_params) }
        it "assigns passed parameters, assigns close_serials" do
          get :index, params: query_params
          expect(response.status).to eq 200
          expect(assigns(:interpreted_params)).to eq target_interpreted_params
          expect(assigns(:selected_query_items_options)).to eq target_selected_query_items_options
          expect(assigns(:bikes).map(&:id)).to eq([])
        end
      end
      context "ip proximity" do
        let(:query_params) { { location: "yoU", distance: 1, stolenness: "proximity" } }
        before { request.env["HTTP_CF_CONNECTING_IP"] = ip_address }
        context "found location" do
          it "assigns passed parameters and close_serials" do
            allow(Geocoder).to receive(:search) { legacy_production_ip_search_result }
            get :index, params: query_params
            expect(response.status).to eq 200
            expect(assigns(:interpreted_params)).to eq target_interpreted_params
            expect(assigns(:bikes).map(&:id)).to eq([stolen_bike.id])
          end
        end
        context "ip passed as parameter" do
          let(:ip_query_params) { query_params.merge(location: "IP") }
          it "assigns passed parameters and close_serials" do
            allow(Geocoder).to receive(:search) { production_ip_search_result }
            get :index, params: ip_query_params
            expect(response.status).to eq 200
            expect(assigns(:interpreted_params)).to eq target_interpreted_params.merge(location: target_location)
            expect(assigns(:bikes).map(&:id)).to eq([stolen_bike.id])
          end
        end
        context "no location" do
          let(:ip_query_params) { query_params.merge(location: "   ") }
          it "assigns passed parameters and close_serials" do
            allow(Geocoder).to receive(:search) { production_ip_search_result }
            get :index, params: ip_query_params
            expect(response.status).to eq 200
            expect(assigns(:interpreted_params)).to eq target_interpreted_params.merge(location: target_location)
            expect(assigns(:bikes).map(&:id)).to eq([stolen_bike.id])
          end
        end
        context "unknown location" do
          # Override bounding box stub in geocoder_default_location shared context
          let(:bounding_box) { [66.00, -84.22, 67.000, (0.0 / 0)] }
          it "includes a flash[:info] for unknown location, renders non-proximity" do
            get :index, params: query_params
            expect(response.status).to eq 200
            expect(flash[:info]).to match(/location/)
            expect(query_params[:stolenness]).to eq "proximity"
            expect(assigns(:interpreted_params)[:stolenness]).to eq "stolen"
          end
        end
      end
      context "passed all permitted params" do
        let(:query_params) do
          ActionController::Parameters.new(
            query: "1",
            manufacturer: "2",
            colors: %w[3 4],
            location: "5",
            distance: "6",
            serial: "9",
            query_items: %w[7 8],
            stolenness: "all",
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
        it "sends all the params we want to searchable_interpreted_params" do
          request.env["HTTP_CF_CONNECTING_IP"] = "special"
          expect(Bike).to receive(:searchable_interpreted_params).with(query_params, ip: "special") { {} }
          get :index, params: query_params.to_h
          expect(response.status).to eq 200
        end
      end
    end
  end

  describe "show" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership) }
    let(:user) { bike.creator }
    let(:organization) { FactoryBot.create(:organization) }
    it "shows the bike" do
      get :show, params: { id: bike.id }
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(assigns(:bike)).to be_decorated
      expect(flash).to_not be_present
    end
    context "illegally set passive_organization" do
      include_context :logged_in_as_user
      it "renders, resets passive_organization_id" do
        expect(user.default_organization).to be_nil
        session[:passive_organization_id] = organization.id
        get :show, params: { id: bike.id }
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
        expect(assigns(:bike)).to be_decorated
        expect(flash).to_not be_present
        expect(assigns[:current_organization]).to be_nil
        expect(assigns[:passive_organization]).to be_nil
        expect(session[:passive_organization_id]).to eq "0"
      end
    end
    context "Admin with manually set current_organization" do
      include_context :logged_in_as_super_admin
      let(:user) { FactoryBot.create(:organization_member, superuser: true) }
      it "renders, sets passive_organization_id to be passed organization" do
        expect(user.default_organization).to be_present
        expect(user.default_organization).to_not eq organization
        session[:passive_organization_id] = user.default_organization.id
        get :show, params: { id: bike.id, organization_id: organization.name }
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
        expect(assigns(:bike)).to be_decorated
        expect(flash).to_not be_present
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:passive_organization)).to eq organization
        expect(session[:passive_organization_id]).to eq organization.id
      end
    end
    context "assigned sticker" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization, bike: bike, code: "ED09999") }
      it "renders with the sticker assigned" do
        expect(user.authorized?(bike_sticker)).to be_truthy
        get :show, params: { id: bike.id, scanned_id: "ED009999", organization_id: organization.id }
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
        expect(assigns(:bike)).to be_decorated
        expect(flash).to_not be_present
        expect(assigns(:bike_sticker)).to eq bike_sticker
        expect(user.authorized?(assigns(:bike_sticker))).to be_truthy
      end
      context "user not bike owner" do
        let(:user) { FactoryBot.create(:user_confirmed) }
        it "renders with the sticker assigned and user authorized for sticker" do
          expect(user.authorized?(bike_sticker)).to be_falsey
          get :show, params: { id: bike.id, scanned_id: "ED009999", organization_id: organization.id }
          expect(response.status).to eq(200)
          expect(response).to render_template(:show)
          expect(assigns(:bike)).to be_decorated
          expect(flash).to_not be_present
          expect(assigns(:bike_sticker)).to eq bike_sticker
          expect(user.authorized?(assigns(:bike_sticker))).to be_falsey
        end
      end
    end
    # Because we're doing some special stuff with organization bike viewing
    context "organized user viewing bike" do
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      before { set_current_user(user) }
      it "renders" do
        expect(bike.editable_organizations.pluck(:id)).to eq([])
        get :show, params: { id: bike.id }
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
        expect(flash).to_not be_present
        expect(session[:passive_organization_id]).to eq organization.id
        expect(assigns(:passive_organization_authorized)).to be_falsey
        expect(assigns(:passive_organization_registered)).to be_falsey
      end
      # This is mostly legacy - really we don't care about creation organization
      # Leaving this in just for better test coverage
      context "bike created by organization" do
        let(:bike) { FactoryBot.create(:creation_organization_bike, organization: organization) }
        it "renders" do
          expect(bike.editable_organizations.pluck(:id)).to eq([organization.id])
          get :show, params: { id: bike.id }
          expect(response.status).to eq(200)
          expect(response).to render_template(:show)
          expect(flash).to_not be_present
          expect(session[:passive_organization_id]).to eq organization.id
          expect(assigns(:passive_organization_authorized)).to be_truthy
          expect(assigns(:passive_organization_registered)).to be_truthy
        end
      end
      context "bike owned by organization" do
        let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, organization: organization) }
        it "renders" do
          expect(bike.editable_organizations.pluck(:id)).to eq([organization.id])
          get :show, params: { id: bike.id }
          expect(response.status).to eq(200)
          expect(response).to render_template(:show)
          expect(flash).to_not be_present
          expect(session[:passive_organization_id]).to eq organization.id
          expect(assigns(:passive_organization_authorized)).to be_truthy
          expect(assigns(:passive_organization_registered)).to be_truthy
        end
      end
      context "bike owned by organization, without can_edit_claimed" do
        let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, can_edit_claimed: false, organization: organization) }
        it "renders" do
          expect(bike.editable_organizations.pluck(:id)).to eq([])
          get :show, params: { id: bike.id }
          expect(response.status).to eq(200)
          expect(response).to render_template(:show)
          expect(flash).to_not be_present
          expect(session[:passive_organization_id]).to eq organization.id
          expect(assigns(:passive_organization_authorized)).to be_falsey
          expect(assigns(:passive_organization_registered)).to be_truthy
        end
      end
    end
    context "too large of integer bike_id" do
      it "responds with not found" do
        expect do
          get :show, params: { id: 57549641769762268311552 }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    context "qr code gif" do
      it "renders" do
        get :show, params: { id: bike.id, format: :gif }
        expect(response.status).to eq(200)
      end
    end
    context "bike is soft deleted" do
      include_context :logged_in_as_user
      it "redirects the user" do
        bike.destroy
        bike.reload
        expect(bike.deleted?).to be_truthy
        expect do
          get :show, params: { id: bike.id }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
      context "user is super_admin" do
        include_context :logged_in_as_super_admin
        it "shows the bike" do
          bike.destroy
          bike.reload
          get :show, params: { id: bike.id }
          expect(bike.deleted?).to be_truthy
          expect(response.status).to eq(200)
          expect(response).to render_template(:show)
        end
      end
    end
  end

  describe "spokecard" do
    it "renders the page from bike id" do
      bike = FactoryBot.create(:bike)
      get :spokecard, params: { id: bike.id }
      expect(response.code).to eq("200")
    end
  end

  describe "scanned" do
    let(:bike) { FactoryBot.create(:bike) }
    let!(:bike_sticker) { FactoryBot.create(:bike_sticker, bike: bike, code: "D900") }
    let(:organization) { FactoryBot.create(:organization) }
    context "organized no bike" do
      let!(:bike_sticker2) { FactoryBot.create(:bike_sticker, organization: organization, code: "D0900") }
      let!(:user) { FactoryBot.create(:user_confirmed) }
      before { set_current_user(user) }
      it "renders the scanned page" do
        get :scanned, params: { id: "000#{bike_sticker2.code}", organization_id: organization.to_param }
        expect(assigns(:bike_sticker)).to eq bike_sticker2
        expect(response).to render_template(:scanned)
        expect(response.code).to eq("200")
        expect(assigns(:show_organization_bikes)).to be_falsey
        expect(session[:passive_organization_id]).to eq "0"
      end
      context "user part of organization" do
        let!(:user) { FactoryBot.create(:organization_member, organization: organization) }
        it "makes current_organization the organization" do
          get :scanned, params: { id: "D0900", organization_id: organization.to_param }
          expect(assigns(:bike_sticker)).to eq bike_sticker2
          expect(session[:passive_organization_id]).to eq organization.id
          expect(response).to redirect_to organization_bikes_path(organization_id: organization.to_param, bike_sticker: bike_sticker2.code)
        end
        context "passed a different organization id" do
          let!(:other_organization) { FactoryBot.create(:organization, short_name: "BikeIndex") }
          it "makes current_organization the organization" do
            expect(user.memberships&.pluck(:organization_id)).to eq([organization.id])
            expect(bike_sticker2.organization).to eq organization
            get :scanned, params: { id: "D900", organization_id: "BikeIndex" }
            expect(assigns(:bike_sticker)).to eq bike_sticker2
            expect(session[:passive_organization_id]).to eq organization.id
            expect(response).to redirect_to organization_bikes_path(organization_id: organization.to_param, bike_sticker: bike_sticker2.code)
          end
        end
      end
    end
    context "code_id" do
      it "redirects to the proper page" do
        get :scanned, params: { card_id: " 000000900" }
        expect(response).to redirect_to bike_url(bike)
      end
    end
    context "unknown code" do
      it "redirects to user root, flash error present" do
        get :scanned, params: { card_id: " 1393242" }
        expect(response).to redirect_to root_path
        expect(flash[:error]).to be_present
      end
    end
    context "code_id" do
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker, code: "sss", bike: bike) }
      it "redirects to the proper page" do
        get :scanned, params: { scanned_id: "sss" }
        expect(response).to redirect_to bike_url(bike, scanned_id: "sss")
      end
      context "organization bike code" do
        let(:organization) { FactoryBot.create(:organization) }
        let(:code) { "XD934292" }
        let!(:bike_sticker) { FactoryBot.create(:bike_sticker, code: code, organization_id: organization.id, bike: bike) }
        it "redirects to the proper page" do
          get :scanned, params: { scanned_id: code, organization_id: organization.id }
          expect(response).to redirect_to bike_url(bike, scanned_id: code, organization_id: organization.id)
        end
      end
    end
    context "id" do
      it "redirects to the proper page" do
        get :scanned, params: { id: 900 }
        expect(response).to redirect_to bike_url(bike)
      end
    end
  end

  describe "new" do
    context "not signed in" do
      it "sets redirect_to" do
        get :new, params: { stolen: true, b_param_token: "cool-token-thing" }
        expect(response).to redirect_to new_user_url
        # expect(Rack::Utils.parse_query(session[:discourse_redirect])).to eq(discourse_params)
        expect(flash[:info]).to be_present
        expect(session[:return_to]).to eq new_bike_path(stolen: true, b_param_token: "cool-token-thing")
      end
    end

    context "signed in" do
      include_context :logged_in_as_user
      let(:organization) { FactoryBot.create(:organization) }
      context "passed stolen param" do
        it "renders a new stolen bike" do
          get :new, params: { stolen: true }
          expect(response.code).to eq("200")
          expect(assigns(:bike).stolen).to be_truthy
        end
      end
      context "passed recovered param" do
        it "renders a new recovered bike" do
          get :new, params: { abandoned: true }
          expect(response.code).to eq("200")
          expect(assigns(:bike).abandoned).to be_truthy
        end
      end
      context "with organization id" do
        it "renders and assigns creation organization" do
          get :new, params: { organization_id: organization.to_param }
          expect(response.code).to eq("200")
          expect(assigns(:bike).creation_organization).to eq organization
          expect(assigns[:passive_organization]).to be_nil # Because the user isn't necessarily a member of an org
        end
      end
      context "with organization member" do
        let(:user) { FactoryBot.create(:organization_member, organization: organization) }
        it "renders and assigns creation_organization" do
          get :new
          expect(response.code).to eq("200")
          expect(assigns(:bike).creation_organization).to eq organization
          expect(assigns[:passive_organization]).to eq organization
        end
      end
      context "stolen from params" do
        it "renders a new stolen bike" do
          get :new, params: { stolen: true }
          expect(response.code).to eq("200")
          expect(assigns(:bike).stolen).to be_truthy
          b_param = assigns(:b_param)
          expect(b_param.revised_new?).to be_truthy
          expect(response).to render_template(:new)
        end
      end
      context "bike through b_param" do
        let(:bike_attrs) do
          {
            manufacturer_id: manufacturer.id,
            primary_frame_color_id: color.id,
            owner_email: "something@stuff.com",
          }
        end
        context "valid b_param" do
          it "renders the bike from b_param" do
            b_param = BParam.create(params: { bike: bike_attrs.merge("revised_new" => true) })
            expect(b_param.id_token).to be_present
            get :new, params: { b_param_token: b_param.id_token }
            bike = assigns(:bike)
            expect(assigns(:b_param)).to eq b_param
            expect(bike.is_a?(Bike)).to be_truthy
            bike_attrs.each { |k, v| expect(bike.send(k)).to eq(v) }
          end
        end
        context "partial registration by organization" do
          let(:organization) { FactoryBot.create(:organization_with_auto_user) }
          let(:organized_bike_attrs) { bike_attrs.merge(creation_organization_id: organization.id) }
          it "renders for the user (even though a different creator)" do
            b_param = BParam.create(params: { bike: organized_bike_attrs.merge("revised_new" => true) })
            expect(b_param.id_token).to be_present
            get :new, params: { b_param_token: b_param.id_token }
            bike = assigns(:bike)
            expect(assigns(:b_param)).to eq b_param
            expect(bike.is_a?(Bike)).to be_truthy
            organized_bike_attrs.each do |k, v|
              pp k unless bike.send(k) == v
              expect(bike.send(k)).to eq(v)
            end
            expect(assigns(:organization)).to eq organization
          end
        end
        context "invalid b_param" do
          it "renders a new bike, has a flash message" do
            b_param = BParam.create(creator_id: FactoryBot.create(:user).id)
            expect(b_param.id_token).to be_present
            get :new, params: { b_param_token: b_param.id_token }
            bike = assigns(:bike)
            expect(bike.is_a?(Bike)).to be_truthy
            expect(assigns(:b_param)).to_not eq b_param
            expect(flash[:info]).to match(/couldn.t find/i)
          end
        end
      end
      context "created bike" do
        let(:bike) { FactoryBot.create(:bike) }
        let(:b_param) { BParam.create(params: { bike: {} }, created_bike_id: bike.id, creator_id: user.id) }
        it "redirects to the bike" do
          expect(b_param.created_bike).to be_present
          get :new, params: { b_param_token: b_param.id_token }
          expect(response).to redirect_to(bike_path(bike.id))
        end
      end
    end
  end

  describe "create" do
    # This is the create action for bikes controller
    let(:cycle_type) { "tandem" }
    let(:handlebar_type) { "bmx" }
    let(:chicago_stolen_params) do
      {
        country_id: country.id,
        street: "2459 W Division St",
        city: "Chicago",
        zipcode: "60622",
        state_id: state.id,
      }
    end

    describe "embedded" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user) }
      let(:user) { organization.auto_user }
      let(:b_param) { BParam.create(creator_id: organization.auto_user.id, params: { creation_organization_id: organization.id, embeded: true }) }
      let(:bike_params) do
        {
          serial_number: "69",
          b_param_id_token: b_param.id_token,
          creation_organization_id: organization.id,
          embeded: true,
          extra_registration_number: "Testly secondary",
          cycle_type_slug: " Tricycle ",
          manufacturer_id: manufacturer.id,
          manufacturer_other: "",
          primary_frame_color_id: color.id,
          handlebar_type: handlebar_type,
          owner_email: "flow@goodtimes.com",
        }
      end
      let(:testable_bike_params) { bike_params.except(:b_param_id_token, :embeded, :cycle_type_slug) }
      context "unverified authenticity token" do
        include_context :test_csrf_token
        it "fails" do
          expect(user).to be_present
          expect do
            post :create, params: { bike: bike_params }
          end.to_not change(Ownership, :count)
          expect(flash[:error]).to match(/csrf/i)
        end
      end
      context "non-stolen" do
        it "creates a new ownership and bike from an organization" do
          expect(user).to be_present
          expect do
            post :create, params: { bike: bike_params }
          end.to change(Ownership, :count).by 1
          bike = Bike.last
          expect(bike.country.name).to eq("United States")
          expect(bike.creation_state.origin).to eq "embed"
          expect(bike.creation_state.organization).to eq organization
          expect(bike.creation_state.creator).to eq bike.creator
          expect(bike.cycle_type).to eq "tricycle"
          testable_bike_params.each do |k, v|
            pp k unless bike.send(k).to_s == v.to_s
            expect(bike.send(k).to_s).to eq v.to_s
          end
        end
      end
      context "with parking_notification" do
        let(:parking_notification) do
          {
            latitude: "40.7143528",
            longitude: "-74.0059731",
            accuracy: "12",
            kind: "parked_incorrectly_notification",
            internal_notes: "some details about the abandoned thing",
            use_entered_address: "false",
            message: "Some message to the user",
            street: "whatever",
          }
        end
        it "registers, doesn't create a parking_notification" do
          expect do
            post :create, params: { bike: bike_params, parking_notification: parking_notification }
          end.to change(Ownership, :count).by 1
          bike = Bike.last
          expect(bike.country.name).to eq("United States")
          expect(bike.creation_state.origin).to eq "embed"
          expect(bike.creation_state.organization).to eq organization
          expect(ParkingNotification.count).to eq 0
        end
      end
      context "stolen" do
        let(:target_time) { Time.current.to_i }
        let(:stolen_params) { chicago_stolen_params.merge(date_stolen: (Time.current - 1.day).utc, timezone: "UTC") }
        context "valid" do
          include_context :geocoder_real
          context "with old style date input" do
            it "creates a new ownership and bike from an organization" do
              VCR.use_cassette("bikes_controller-create-stolen-chicago", match_requests_on: [:path]) do
                expect do
                  post :create, params: { bike: bike_params.merge(stolen: true), stolen_record: stolen_params }
                  expect(assigns(:bike).errors&.full_messages).to_not be_present
                end.to change(Ownership, :count).by 1
                bike = Bike.last
                expect(bike).to be_present
                expect(bike.creation_state.origin).to eq "embed"
                expect(bike.creation_state.organization).to eq organization
                expect(bike.creation_state.creator).to eq bike.creator
                testable_bike_params.each { |k, v| expect(bike.send(k).to_s).to eq v.to_s }
                stolen_record = bike.current_stolen_record
                stolen_params.except(:date_stolen, :timezone).each { |k, v| expect(stolen_record.send(k).to_s).to eq v.to_s }
                expect(stolen_record.date_stolen.to_i).to be_within(1).of(Time.current.yesterday.to_i)
                expect(stolen_record.show_address).to be_falsey
              end
            end
          end
          context "new date input" do
            let(:alt_stolen_params) { stolen_params.merge(date_stolen: "2018-07-28T23:34:00", timezone: "America/New_York") }
            let(:target_time) { 1532835240 }
            it "creates a new ownership and bike from an organization" do
              VCR.use_cassette("bikes_controller-create-stolen-chicago", match_requests_on: [:path]) do
                expect do
                  post :create, params: { bike: bike_params.merge(stolen: true), stolen_record: alt_stolen_params }
                end.to change(Ownership, :count).by 1
                bike = Bike.last
                expect(bike).to be_present
                expect(bike.creation_state.origin).to eq "embed"
                expect(bike.creation_state.organization).to eq organization
                expect(bike.creation_state.creator).to eq bike.creator
                testable_bike_params.each { |k, v| expect(bike.send(k).to_s).to eq v.to_s }
                stolen_record = bike.current_stolen_record
                stolen_params.except(:date_stolen, :timezone).each { |k, v| expect(stolen_record.send(k).to_s).to eq v.to_s }
                expect(stolen_record.date_stolen.to_i).to be_within(1).of target_time
              end
            end
          end
        end
        context "invalid" do
          it "renders the stolen form with all the attributes" do
            target_path = embed_organization_path(id: organization.slug, b_param_id_token: b_param.id_token)

            expect do
              post :create, params: { bike: bike_params.merge(stolen: "1", serial_number: nil), stolen_record: stolen_params }

              expect(assigns(:bike).errors&.full_messages).to be_present
            end.to change(Ownership, :count).by(0)

            expect(response).to redirect_to target_path
            bike = assigns(:bike)
            testable_bike_params
              .except(:serial_number)
              .each { |k, v| expect(bike.send(k).to_s).to eq(v.to_s) }
            expect(bike.stolen).to be_truthy
            # we retain the stolen record attrs, it would be great to test that they are
            # assigned correctly, but I don't know how - it needs to completely
            # render the new action
          end
        end
      end
    end

    describe "extended embeded submission" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user) }
      let(:bike_params) do
        {
          serial_number: "69",
          b_param_id_token: b_param.id_token,
          creation_organization_id: organization.id,
          embeded: true,
          embeded_extended: true,
          cycle_type: "pedi-cab",
          manufacturer_id: manufacturer.slug,
          primary_frame_color_id: color.id,
          handlebar_type: handlebar_type,
          owner_email: "Flow@goodtimes.com",
        }
      end
      let(:b_param) { BParam.create(creator_id: organization.auto_user.id, params: { creation_organization_id: organization.id, embeded: true }) }
      before do
        expect(b_param).to be_present
      end
      context "with an image" do
        it "registers a bike and uploads an image" do
          Sidekiq::Testing.inline! do
            test_photo = Rack::Test::UploadedFile.new(File.open(File.join(Rails.root, "spec", "fixtures", "bike.jpg")))
            post :create, params: { persist_email: "", bike: bike_params.merge(image: test_photo) }
            expect(assigns[:persist_email]).to be_falsey
            expect(response).to redirect_to(embed_extended_organization_url(organization))
            # Have to do after, because inline sidekiq ignores delays and created_bike isn't present when it's run
            ImageAssociatorWorker.new.perform
            bike = Bike.last
            expect(bike.owner_email).to eq bike_params[:owner_email].downcase
            expect(bike.creation_state.origin).to eq "embed_extended"
            expect(bike.creation_state.organization).to eq organization
            expect(bike.creation_state.creator).to eq bike.creator
            expect(bike.cycle_type_name).to eq "Pedi Cab (rickshaw)"
            expect(bike.manufacturer).to eq manufacturer
            expect(bike.public_images.count).to eq 1
          end
        end
      end
      context "with persisted email and non-member and parent organization" do
        let(:organization_parent) { FactoryBot.create(:organization) }
        let(:organization) { FactoryBot.create(:organization_with_auto_user, parent_organization_id: organization_parent.id) }
        let!(:user2) { FactoryBot.create(:user_confirmed) }
        it "registers a bike and redirects with persist_email" do
          set_current_user(user2)
          post :create, params: { bike: bike_params.merge(manufacturer_id: "A crazy different thing"), persist_email: true }
          expect(assigns[:persist_email]).to be_truthy
          expect(response).to redirect_to(embed_extended_organization_url(organization, email: "flow@goodtimes.com"))
          bike = Bike.last
          expect(bike.creation_state.origin).to eq "embed_extended"
          expect(bike.creation_state.organization).to eq organization
          expect(bike.creation_state.creator).to eq bike.creator
          expect(bike.manufacturer).to eq Manufacturer.other
          expect(bike.manufacturer_other).to eq "A crazy different thing"
          expect(bike.creator_id).to eq organization.auto_user_id # It isn't registered to the signed in user
          expect(bike.organizations.pluck(:id)).to match_array([organization.id, organization_parent.id])
        end
      end
      context "with organization bike code and signed in member" do
        let!(:user) { FactoryBot.create(:organization_member, organization: organization) }
        let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization, code: "aaa", kind: "sticker") }
        let!(:wrong_bike_sticker) { FactoryBot.create(:bike_sticker, code: "aaa", kind: "sticker") }
        it "registers a bike under signed in user and redirects with persist_email" do
          set_current_user(user)
          post :create, params: { bike: bike_params.merge(bike_sticker: "AAA") }
          expect(response).to redirect_to(embed_extended_organization_url(organization))
          bike = Bike.last
          expect(bike.creation_state.origin).to eq "embed_extended"
          expect(bike.creation_state.organization).to eq organization
          expect(bike.creation_state.creator).to eq bike.creator
          expect(bike.creation_state.creator).to eq bike.creator
          expect(bike.manufacturer).to eq manufacturer
          expect(bike.creator_id).to eq user.id
          bike_sticker.reload
          expect(bike_sticker.claimed?).to be_truthy
          expect(bike_sticker.bike).to eq bike
          expect(bike_sticker.user).to eq bike.creator
          wrong_bike_sticker.reload
          expect(wrong_bike_sticker.claimed?).to be_falsey
        end
      end
    end

    context "standard web form submission" do
      include_context :logged_in_as_user
      describe "blank serials" do
        let(:bike_params) do
          {
            serial_number: "unknown",
            manufacturer_id: manufacturer.name,
            primary_frame_color_id: color.id,
            owner_email: user.email,
            made_without_serial: "0",
          }
        end
        it "creates" do
          expect(user.bikes.count).to eq 0
          expect do
            post :create, params: { bike: bike_params }
          end.to change(Ownership, :count).by(1)
          expect(user.bikes.count).to eq 1
          bike = user.bikes.first
          expect(bike.claimed?).to be_truthy
          expect(bike.no_serial?).to be_truthy
          expect(bike.made_without_serial?).to be_falsey
          expect(bike.serial_unknown?).to be_truthy
          expect(bike.serial_number).to eq "unknown"
          expect(bike.normalized_serial_segments).to eq([])
        end
        context "made_without_serial" do
          it "creates, is made_without_serial" do
            expect(user.bikes.count).to eq 0
            expect do
              post :create, params: { bike: bike_params.merge(made_without_serial: "1") }
            end.to change(Ownership, :count).by(1)
            expect(user.bikes.count).to eq 1
            bike = user.bikes.first
            expect(bike.claimed?).to be_truthy
            expect(bike.no_serial?).to be_truthy
            expect(bike.made_without_serial?).to be_truthy
            expect(bike.serial_unknown?).to be_falsey
            expect(bike.serial_number).to eq "made_without_serial"
            expect(bike.normalized_serial_segments).to eq([])
          end
        end
      end

      context "legacy b_param" do
        let(:bike_params) do
          {
            serial_number: "1234567890",
            b_param_id_token: b_param.id_token,
            cycle_type: "stroller",
            manufacturer_id: manufacturer.name,
            rear_tire_narrow: "true",
            rear_wheel_size_id: FactoryBot.create(:wheel_size).id,
            primary_frame_color_id: color.id,
            handlebar_type: handlebar_type,
            owner_email: user.email,
          }
        end

        context "b_param not owned by user" do
          let(:other_user) { FactoryBot.create(:user) }
          let(:b_param) { FactoryBot.create(:b_param, creator: other_user) }
          it "does not use the b_param if isn't owned by user" do
            post :create, params: { bike: bike_params }
            b_param.reload
            expect(b_param.created_bike_id).to_not be_present
          end
        end

        context "stolen b_param from user" do
          let(:b_param) { FactoryBot.create(:b_param, creator: user) }
          it "creates a new stolen bike and assigns the user phone" do
            expect do
              post :create, params: { stolen: "true", bike: bike_params.merge(phone: "312.379.9513") }
            end.to change(StolenRecord, :count).by(1)
            expect(b_param.reload.created_bike_id).not_to be_nil
            expect(b_param.reload.bike_errors).to be_nil
            expect(b_param.image_processed).to be_falsey
            expect(user.reload.phone).to eq("3123799513")
          end
        end
        context "organization b_param" do
          let(:organization) { FactoryBot.create(:organization_with_auto_user) }
          let(:b_param) { FactoryBot.create(:b_param, creator: organization.auto_user) }
          it "creates a new ownership and bike from an organization" do
            expect do
              post :create, params: { bike: bike_params.merge(creation_organization_id: organization.id) }
            end.to change(Ownership, :count).by(1)
            expect(Bike.last.creation_organization_id).to eq(organization.id)
          end
        end
      end

      context "no existing b_param and stolen" do
        let(:wheel_size) { FactoryBot.create(:wheel_size) }
        let(:bike_params) do
          {
            b_param_id_token: "",
            cycle_type: "tall-bike",
            serial_number: "example serial",
            manufacturer_other: "",
            year: "2016",
            frame_model: "Cool frame model",
            primary_frame_color_id: color.id.to_s,
            secondary_frame_color_id: "",
            tertiary_frame_color_id: "",
            owner_email: "something@stuff.com",
            phone: "312.379.9513",
            stolen: true,
          }
        end
        before { expect(BParam.all.count).to eq 0 }
        context "successful creation" do
          include_context :geocoder_real
          it "creates a bike and doesn't create a b_param" do
            bike_user = FactoryBot.create(:user_confirmed, email: "something@stuff.com")
            VCR.use_cassette("bikes_controller-create-stolen-chicago", match_requests_on: [:path]) do
              success_params = bike_params.merge(manufacturer_id: manufacturer.slug)
              bb_data = { bike: { rear_wheel_bsd: wheel_size.iso_bsd.to_s }, components: [] }.as_json
              # We need to call clean_params on the BParam after bikebook update, so that
              # the foreign keys are assigned correctly. This is how we test that we're
              # This is also where we're testing bikebook assignment
              expect_any_instance_of(BikeBookIntegration).to receive(:get_model) { bb_data }
              expect do
                post :create, params: { stolen: true, bike: success_params.as_json, stolen_record: chicago_stolen_params.merge(show_address: true) }
              end.to change(Bike, :count).by(1)
              expect(flash[:success]).to be_present
              expect(BParam.all.count).to eq 0
              bike = Bike.last
              bike_params.except(:manufacturer_id, :phone).each { |k, v| expect(bike.send(k).to_s).to eq v.to_s }
              expect(bike.manufacturer).to eq manufacturer
              expect(bike.stolen).to be_truthy
              bike_user.reload
              expect(bike.current_stolen_record.phone).to eq "3123799513"
              expect(bike_user.phone).to eq "3123799513"
              stolen_record = bike.current_stolen_record
              chicago_stolen_params.except(:state_id).each { |k, v| expect(stolen_record.send(k).to_s).to eq v.to_s }
              expect(stolen_record.show_address).to be_truthy
            end
          end
        end
        context "failure" do
          it "assigns a bike and a stolen record with the attrs passed" do
            expect do
              post :create, params: { stolen: true, bike: bike_params.as_json, stolen_record: chicago_stolen_params }
            end.to change(Bike, :count).by(0)
            expect(BParam.all.count).to eq 1
            bike = assigns(:bike)
            bike_params.delete(:manufacturer_id)
            bike_params.delete(:phone)
            bike_params.each { |k, v| expect(bike.send(k).to_s).to eq v.to_s }
            expect(bike.stolen).to be_truthy
            # we retain the stolen record attrs, it would be great to test that they are
            # assigned correctly, but I don't know how - it needs to completely
            # render the new action
            # stolen_record = assigns(:stolen_record)
            # chicago_stolen_params.each { |k, v| expect(stolen_record.send(k).to_s).to eq v.to_s }
          end
        end
      end
      context "existing b_param" do
        context "no bike" do
          let(:bike_params) do
            {
              cycle_type: "cargo-rear",
              serial_number: "example serial",
              manufacturer_other: "",
              year: "2016",
              frame_model: "Cool frame model",
              primary_frame_color_id: color.id.to_s,
              secondary_frame_color_id: "",
              tertiary_frame_color_id: "",
              owner_email: "something@stuff.com",
            }
          end
          let(:target_address) { { street: "278 Broadway", city: "New York", state: "NY", zipcode: "10007", country: "US", latitude: 40.7143528, longitude: -74.0059731 } }
          let(:b_param) { BParam.create(params: { "bike" => bike_params.as_json }, origin: "embed_partial") }
          before do
            expect(b_param.partial_registration?).to be_truthy
            bb_data = { bike: {} }
            # We need to call clean_params on the BParam after bikebook update, so that
            # the foreign keys are assigned correctly. This is how we test that we're
            # This is also where we're testing bikebook assignment
            expect_any_instance_of(BikeBookIntegration).to receive(:get_model) { bb_data }
          end
          it "creates a bike" do
            expect do
              post :create, params: {
                              bike: {
                                manufacturer_id: manufacturer.slug,
                                b_param_id_token: b_param.id_token,
                                address: default_location[:address],
                                extra_registration_number: "XXXZZZ",
                                organization_affiliation: "employee",
                                phone: "888.777.6666",
                              },
                            }
            end.to change(Bike, :count).by(1)
            expect(flash[:success]).to be_present
            bike = Bike.last
            expect(bike.creator_id).to eq user.id
            b_param.reload
            expect(b_param.created_bike_id).to eq bike.id
            expect(b_param.phone).to eq "888.777.6666"
            bike_params.delete(:manufacturer_id)
            bike_params.each { |k, v| expect(bike.send(k).to_s).to eq v }
            expect(bike.manufacturer).to eq manufacturer
            expect(bike.creation_state.origin).to eq "embed_partial"
            expect(bike.creation_state.creator).to eq bike.creator
            expect(bike.registration_address).to eq target_address.as_json
            expect(bike.extra_registration_number).to eq "XXXZZZ"
            expect(bike.organization_affiliation).to eq "employee"
            expect(bike.phone).to eq "888.777.6666"
            user.reload
            expect(bike.owner).to eq user # NOTE: not bike user
            expect(user.phone).to be_nil # Because the phone doesn't set for the creator
          end
          context "updated address" do
            # Too many mistakes with the old method, so switching to some new shiz
            let(:target_address) { { street: "212 Main St", city: "Chicago", state: "IL", zipcode: "60647" } }
            it "creates the bike and does the updated address thing" do
              expect do
                post :create, params: {
                                bike: {
                                  manufacturer_id: manufacturer.slug,
                                  b_param_id_token: b_param.id_token,
                                  street: "212 Main St",
                                  city: "Chicago",
                                  state: "IL",
                                  zipcode: "60647",
                                  extra_registration_number: " ",
                                  organization_affiliation: "student",
                                  phone: "8887776666",
                                },
                              }
              end.to change(Bike, :count).by(1)
              expect(flash[:success]).to be_present
              bike = Bike.last
              b_param.reload
              expect(b_param.created_bike_id).to eq bike.id
              bike_params.delete(:manufacturer_id)
              bike_params.each { |k, v| expect(bike.send(k).to_s).to eq v }
              expect(bike.manufacturer).to eq manufacturer
              expect(bike.creation_state.origin).to eq "embed_partial"
              expect(bike.creation_state.creator).to eq bike.creator
              expect(bike.registration_address).to eq target_address.as_json
              expect(bike.state.name).to eq "Illinois"
              expect(bike.extra_registration_number).to be_blank
              expect(bike.organization_affiliation).to eq "student"
              expect(bike.phone).to eq "8887776666"
              user.reload
              expect(bike.owner).to eq user # NOTE: not bike user
              expect(user.phone).to be_nil # Because the phone doesn't set for the creator
            end
            context "legacy address" do
              it "returns with address" do
                Country.united_states # Ensure it's around
                expect do
                  post :create, params: {
                                  bike: {
                                    manufacturer_id: manufacturer.slug,
                                    b_param_id_token: b_param.id_token,
                                    address: "212 Main St",
                                    address_city: "Chicago",
                                    address_state: "IL",
                                    address_zipcode: "60647",
                                    extra_registration_number: " ",
                                    organization_affiliation: "student",
                                    phone: "8887776666",
                                  },
                                }
                end.to change(Bike, :count).by(1)
                expect(flash[:success]).to be_present
                bike = Bike.last
                b_param.reload
                expect(b_param.address_hash.except("country")).to eq target_address.as_json
                expect(b_param.created_bike_id).to eq bike.id
                bike_params.delete(:manufacturer_id)
                bike_params.each { |k, v| expect(bike.send(k).to_s).to eq v }
                expect(bike.manufacturer).to eq manufacturer
                expect(bike.creation_state.origin).to eq "embed_partial"
                expect(bike.creation_state.creator).to eq bike.creator
                expect(bike.registration_address).to eq target_address.as_json
                expect(bike.state.abbreviation).to eq "IL"
                expect(bike.extra_registration_number).to be_blank
                expect(bike.organization_affiliation).to eq "student"
                expect(bike.phone).to eq "8887776666"
                user.reload
                expect(bike.owner).to eq user # NOTE: not bike user
                expect(user.phone).to be_nil # Because the phone doesn't set for the creator
              end
            end
          end
        end
        context "created bike" do
          it "redirects to the bike" do
            bike = FactoryBot.create(:bike)
            b_param = BParam.create(params: { bike: {} }, created_bike_id: bike.id, creator_id: user.id)
            expect(b_param.created_bike).to be_present
            post :create, params: { bike: { b_param_id_token: b_param.id_token } }
            expect(response).to redirect_to(edit_bike_url(bike.id))
          end
        end
      end
    end
  end

  describe "edit" do
    let(:ownership) { FactoryBot.create(:ownership) }
    let(:bike) { ownership.bike }
    let(:bike_templates) do
      {
        bike_details: "Bike Details",
        photos: "Photos",
        drivetrain: "Wheels and Drivetrain",
        accessories: "Accessories and Components",
        ownership: "Transfer Ownership",
        groups: "Groups and Organizations",
        remove: "Hide or Delete",
        report_stolen: "Report Stolen or Missing",
      }
    end
    let(:theft_templates) do
      {
        theft_details: "Theft details",
        publicize: "Share on Social Media",
        alert: "Activate Promoted Alert",
        report_recovered: "Mark this Bike Recovered",
      }
    end
    let(:edit_templates) do
      theft_templates.merge(bike_templates)
    end
    let(:non_stolen_edit_templates) { bike_templates }
    let(:stolen_edit_templates) { edit_templates.except(:report_stolen) }
    let(:recovery_edit_templates) {
      edit_templates
        .merge(theft_details: "Recovery details")
        .except(:report_stolen, :report_recovered)
    }

    context "no user" do
      it "redirects and sets the flash" do
        get :edit, params: { id: bike.id }
        expect(response).to redirect_to bike_path(bike)
        expect(flash[:error]).to be_present
      end
    end
    context "user present" do
      let(:user) { FactoryBot.create(:user_confirmed) }
      before { set_current_user(user) }
      context "user present but isn't allowed to edit the bike" do
        it "redirects and sets the flash" do
          FactoryBot.create(:user)
          get :edit, params: { id: bike.id }
          expect(response).to redirect_to bike_path(bike)
          expect(flash[:error]).to be_present
        end
      end
      context "user present but hasn't claimed the bike" do
        it "claims and renders" do
          ownership.update_attribute :user_id, user.id
          expect(bike.owner).to_not eq user
          get :edit, params: { id: bike.id }
          bike.reload
          expect(bike.owner).to eq user
          expect(response).to be_ok
          expect(assigns(:edit_template)).to eq "bike_details"
        end
      end
      context "not-creator but member of creation_organization" do
        let(:ownership) { FactoryBot.create(:ownership_organization_bike) }
        let(:organization) { bike.creation_organization }
        let(:user) { FactoryBot.create(:organization_member, organization: organization) }
        it "renders" do
          expect(bike.owner).to_not eq user
          expect(bike.creation_organization).to eq user.organizations.first
          get :edit, params: { id: bike.id }
          expect(response).to be_ok
          expect(assigns(:edit_template)).to eq "bike_details"
        end
      end
    end
    context "user allowed to edit the bike, general alert" do
      let(:user) { ownership.creator }
      context "revised" do
        before do
          user.update_column :general_alerts, ["stolen_bikes_without_locations"]
          set_current_user(user)
        end
        context "root" do
          context "non-stolen bike" do
            it "renders the bike_details template" do
              get :edit, params: { id: bike.id }
              expect(response.status).to eq(200)
              expect(assigns(:edit_template)).to eq "bike_details"
              expect(assigns(:edit_templates)).to eq non_stolen_edit_templates.as_json
              expect(response).to render_template "edit_bike_details"
              expect(assigns(:show_general_alert)).to be_truthy
            end
          end
          context "stolen bike" do
            let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: bike) }
            it "renders with stolen as first template, different description" do
              expect(bike.reload.stolen).to eq(true)
              expect(bike.current_stolen_record.without_location?).to be_truthy
              get :edit, params: { id: bike.id }

              expect(response).to be_ok
              expect(assigns(:edit_template)).to eq "theft_details"
              expect(assigns(:edit_templates)).to eq stolen_edit_templates.as_json
              expect(assigns(:show_general_alert)).to be_falsey
              expect(response).to render_template "edit_theft_details"
            end
          end
          context "recovered bike" do
            it "renders with recovered as first template, different description" do
              bike.update_attributes(stolen: true, abandoned: true)
              bike.reload
              expect(bike.abandoned).to be_truthy

              get :edit, params: { id: bike.id }

              expect(response).to be_ok
              expect(assigns(:edit_template)).to eq "theft_details"
              expect(assigns(:edit_templates)).to eq recovery_edit_templates.as_json
              expect(response).to render_template "edit_theft_details"
            end
          end
          context "unknown template" do
            it "renders the bike_details template" do
              get :edit, params: { id: bike.id, page: "root_party" }
              expect(response).to redirect_to(edit_bike_url(bike, params: { page: :bike_details }))
              expect(assigns(:edit_template)).to eq "bike_details"
              expect(assigns(:edit_templates)).to eq non_stolen_edit_templates.as_json
            end
          end
        end
        context "test all the templates" do
          let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: bike) }
          let(:templates) do
            # Grab all the template keys from the controller so we can test that we
            # render all of them Both to ensure we get all of them and because we
            # can't use the let block
            bc = BikesController.new
            bc.instance_variable_set(:@bike, Bike.new(stolen: true))
            bc.edit_templates.keys + ["alert_purchase", "alert_purchase_confirmation"]
          end
          let(:no_global_alert_templates) { %w[theft_details alert photos report_recovered remove alert_purchase alert_purchase_confirmation] }
          before { FactoryBot.create_list(:theft_alert_plan, 3) }
          it "renders the template" do
            # Ensure stolen bike is set up correctly
            stolen_record.reload
            bike.reload
            expect(bike.current_stolen_record).to eq stolen_record
            expect(bike.current_stolen_record.without_location?).to be_truthy
            expect(stolen_record.theft_alert_missing_photo?).to be_falsey

            templates.each do |template|
              get :edit, params: { id: bike.id, page: template }

              expect(response.status).to eq(200)
              expect(response).to render_template("edit_#{template}")
              expect(assigns(:edit_template)).to eq(template)
              expect(assigns(:private_images)).to eq([]) if template == "photos"
              expect(assigns(:theft_alerts)).to eq([]) if template == "alert"

              should_show_general_alert = !no_global_alert_templates.include?(template)
              pp template unless assigns(:show_general_alert) == should_show_general_alert
              expect(assigns(:show_general_alert)).to eq should_show_general_alert
            end
          end
          context "with a purchased alert and stolen location" do
            it "does not render show_general_alert on photos" do
              user.update_attributes(general_alerts: ["theft_alert_without_photo"])

              templates.each do |template|
                get :edit, params: { id: bike.id, page: template }

                expect(response.status).to eq(200)
                expect(response).to render_template("edit_#{template}")
                expect(assigns(:edit_template)).to eq(template)
                expect(assigns(:private_images)).to eq([]) if template == "photos"
                expect(assigns(:theft_alerts)).to eq([]) if template == "alert"
                show_general_alert = ! %w[theft_details alert photos report_recovered remove alert_purchase alert_purchase_confirmation].include?(template)
                pp template unless assigns(:show_general_alert) == show_general_alert
                expect(assigns(:show_general_alert)).to eq(show_general_alert)
              end
            end
          end
        end
      end
    end
  end

  describe "update" do
    context "user is present but is not allowed to edit" do
      it "does not update and redirects" do
        ownership = FactoryBot.create(:ownership)
        user = FactoryBot.create(:user_confirmed)
        set_current_user(user)
        put :update, params: { id: ownership.bike_id, bike: { serial_number: "69" } }
        expect(response).to redirect_to bike_url(ownership.bike)
        expect(flash[:error]).to be_present
      end
    end

    context "creator present (who is allowed to edit)" do
      let(:ownership) { FactoryBot.create(:ownership) }
      let(:user) { ownership.creator }
      let(:bike) { ownership.bike }
      before { set_current_user(user) }
      context "legacy" do
        it "allows you to edit an example bike" do
          # Also test that we don't don't blank bike_organizations
          # if bike_organization_ids aren't passed
          organization = FactoryBot.create(:organization)
          ownership.bike.update_attributes(example: true, bike_organization_ids: [organization.id])
          bike.reload
          expect(bike.bike_organization_ids).to eq([organization.id])
          put :update, params: { id: bike.id, bike: { description: "69" } }
          expect(response).to redirect_to edit_bike_url(bike)
          bike.reload
          expect(bike.description).to eq("69")
          expect(bike.bike_organization_ids).to eq([organization.id])
        end

        it "updates the bike and components" do
          component1 = FactoryBot.create(:component, bike: bike)
          other_handlebar_type = "other"
          ctype_id = component1.ctype_id
          bike.update(country: Country.united_states)
          bike.reload
          component2_attrs = {
            _destroy: "0",
            ctype_id: ctype_id,
            description: "sdfsdfsdf",
            manufacturer_id: bike.manufacturer_id.to_s,
            manufacturer_other: "stuffffffff",
            cmodel_name: "asdfasdf",
            year: "1995",
            serial_number: "simple_serial",
          }
          bike_attrs = {
            description: "69",
            handlebar_type: other_handlebar_type,
            handlebar_type_other: "Joysticks",
            owner_email: "  #{bike.owner_email.upcase}",
            city: "Rotterdam",
            zipcode: "3035",
            country_id: Country.netherlands.id,
            components_attributes: {
              "0" => {
                "_destroy" => "1",
                id: component1.id.to_s,
              },
              Time.current.to_i.to_s => component2_attrs,
            },
          }
          expect do
            put :update, params: { id: bike.id, bike: bike_attrs }
          end.to_not change(Ownership, :count)
          bike.reload
          expect(bike.description).to eq("69")
          expect(response).to redirect_to edit_bike_url(bike)
          expect(bike.handlebar_type).to eq other_handlebar_type
          expect(bike.handlebar_type_other).to eq "Joysticks"
          expect(assigns(:bike)).to be_decorated
          expect(bike.hidden).to be_falsey
          expect(bike.country&.name).to eq(Country.netherlands.name)
          expect(bike.zipcode).to eq "3035"
          expect(bike.city).to eq "Rotterdam"


          expect(bike.components.count).to eq 1
          expect(bike.components.where(id: component1.id).any?).to be_falsey
          component2 = bike.components.first
          component2_attrs.except(:_destroy).each do |key, value|
            expect(component2.send(key).to_s).to eq value.to_s
          end
        end

        it "marks the bike unhidden" do
          bike.update(marked_user_hidden: "1")
          expect(bike.hidden).to be_truthy
          put :update, params: { id: bike.id, bike: { marked_user_unhidden: "true" } }
          expect(bike.reload.hidden).to be_falsey
        end

        context "bike_sticker" do
          let(:bike_attrs) { { description: "42", handlebar_type: "drop_bar" } }
          let!(:bike_sticker) { FactoryBot.create(:bike_sticker, code: "a00100") }
          it "updates and applies the bike code" do
            expect(bike.bike_stickers.count).to eq 0
            put :update, params: { id: bike.id, bike: bike_attrs, bike_sticker: "https://bikeindex.org/bikes/scanned/A100?organization_id=europe" }
            expect(flash[:success]).to match(bike_sticker.pretty_code)
            bike.reload
            expect(bike.description).to eq "42"
            expect(bike.handlebar_type).to eq "drop_bar"
            expect(bike.bike_stickers.count).to eq 1
            bike_sticker.reload
            expect(bike_sticker.claimed?).to be_truthy
            expect(bike_sticker.bike).to eq bike
            expect(bike_sticker.user).to eq user
          end
          context "bike already has a bike code" do
            let!(:bike_sticker_claimed) { FactoryBot.create(:bike_sticker_claimed, bike: bike, user: user) }
            it "assigns another bike code, doesn't remove existing" do
              expect(bike.bike_stickers.count).to eq 1
              put :update, params: { id: bike.id, bike: bike_attrs, bike_sticker: "A 100" }
              expect(flash[:success]).to match(bike_sticker.pretty_code)
              bike.reload
              expect(bike.description).to eq "42"
              expect(bike.handlebar_type).to eq "drop_bar"
              expect(bike.bike_stickers.count).to eq 2
              bike_sticker.reload
              expect(bike_sticker.claimed?).to be_truthy
              expect(bike_sticker.bike).to eq bike
              expect(bike_sticker.user).to eq bike.creator
              bike_sticker_claimed.reload
            end
            context "not allowed to assign another code" do
              before { stub_const("BikeSticker::MAX_UNORGANIZED", 1) }
              it "renders errors" do
                expect(bike.bike_stickers.count).to eq 1
                put :update, params: { id: bike.id, bike: bike_attrs, bike_sticker: "A 100" }
                expect(flash[:error]).to be_present
                bike.reload
                expect(bike.description).to eq "42"
                expect(bike.handlebar_type).to eq "drop_bar"
                expect(bike.bike_stickers.count).to eq 1
              end
            end
          end
          context "bike code not found" do
            it "renders errors" do
              expect(bike.bike_stickers.count).to eq 0
              put :update, params: { id: bike.id, bike: bike_attrs, bike_sticker: "A 10" }
              expect(flash[:error]).to be_present
              bike.reload
              expect(bike.description).to eq "42"
              expect(bike.handlebar_type).to eq "drop_bar"
              expect(bike.bike_stickers.count).to eq 0
            end
          end
        end

        context "owner email changes" do
          let(:email) { "originalemail@example.com" }
          let(:new_email) { "new@email.com" }
          let(:ownership) { FactoryBot.create(:ownership, creator: user, owner_email: "otheroriginal@email.com") }
          let(:user) { FactoryBot.create(:user_confirmed, email: email) }
          before do
            bike.reload
            ActionMailer::Base.deliveries = []
            Sidekiq::Worker.clear_all
            Sidekiq::Testing.inline!
          end
          after { Sidekiq::Testing.fake! }

          def expect_bike_transferred_but_unclaimed(bike, user)
            bike.reload
            ownership.reload
            expect(ownership.current?).to be_falsey
            expect(bike.owner_email).to eq new_email
            expect(bike.user).to be_nil # Because the new owner hasn't claimed the ownership yet
            expect(bike.claimed?).to be_falsey
            expect(bike.current_ownership.id).to_not eq ownership.id
            current_ownership = bike.current_ownership
            expect(current_ownership.creator_id).to eq user.id
            expect(current_ownership.owner_email).to eq new_email
            expect(ActionMailer::Base.deliveries.count).to eq 1
            mail = ActionMailer::Base.deliveries.last
            expect(mail.subject).to eq("Confirm your Bike Index registration")
            expect(mail.reply_to).to eq(["contact@bikeindex.org"])
            expect(mail.from).to eq(["contact@bikeindex.org"])
            expect(mail.to).to eq([new_email])
          end
          it "creates a new ownership and emails the new owner" do
            expect(bike.claimed?).to be_falsey
            expect(bike.user).to be_nil
            expect(bike.authorized?(user)).to be_truthy
            expect do
              put :update, params: { id: bike.id, bike: { owner_email: new_email } }
            end.to change(Ownership, :count).by(1)
            expect_bike_transferred_but_unclaimed(bike, user)
            expect(bike.owner).to eq user
            expect(bike.current_ownership.user).to be_nil
            expect(bike.authorized?(user)).to be_truthy
          end
          context "claimed ownership" do
            let(:user) { FactoryBot.create(:user_confirmed, email: email) }
            let(:ownership) { FactoryBot.create(:ownership_claimed, user: user, owner_email: email) }
            it "creates a new ownership and emails the new owner" do
              expect(bike.owner_email).to eq email
              expect(bike.claimed?).to be_truthy
              expect(bike.user).to eq user
              expect(bike.authorized?(user)).to be_truthy
              expect do
                put :update, params: { id: bike.id, bike: { owner_email: "#{new_email.upcase} " } }
              end.to change(Ownership, :count).by(1)
              expect_bike_transferred_but_unclaimed(bike, user)
              expect(bike.owner).to eq user
              expect(bike.current_ownership.user).to be_nil
              expect(bike.authorized?(user)).to be_truthy
            end
          end
        end

        it "redirects to return_to if it's a valid url" do
          session[:return_to] = "/about"
          put :update, params: { id: bike.id, bike: { description: "69", marked_user_hidden: "0" } }
          expect(bike.reload.description).to eq("69")
          expect(response).to redirect_to "/about"
          expect(session[:return_to]).to be_nil
        end

        it "doesn't redirect and clears the session if not a valid url" do
          session[:return_to] = "http://testhost.com/bad_place"
          put :update, params: { id: bike.id, bike: { description: "69", marked_user_hidden: "0" } }
          bike.reload
          expect(bike.description).to eq("69")
          expect(session[:return_to]).to be_nil
          expect(response).to redirect_to edit_bike_url
        end
      end
      context "revised" do
        # We're testing a few things in here:
        # Firstly, new stolen update code paths
        # Also, that we can apply stolen changes to hidden bikes
        # And finally, that it redirects to the correct page
        context "stolen update" do
          let(:stolen_record) { FactoryBot.create(:stolen_record, bike: bike, city: "party") }
          let(:target_time) { 1454925600 }
          let(:stolen_attrs) do
            {
              date_stolen: "2016-02-08 04:00:00",
              timezone: "America/Chicago",
              phone: "9999999999",
              street: "66666666 foo street",
              country_id: country.id,
              city: "Chicago",
              zipcode: "60647",
              state_id: state.id,
              locking_description: "Some description",
              lock_defeat_description: "It was cuttttt",
              theft_description: "Someone stole it and stuff",
              police_report_number: "#444444",
              police_report_department: "department of party",
              secondary_phone: "8888888888",
              proof_of_ownership: 1,
              receive_notifications: 0,
              estimated_value: "1200",
            }
          end
          let(:bike_attrs) do
            {
              stolen: true,
              stolen_records_attributes: {
                "0" => stolen_attrs,
              },
            }
          end
          let(:skipped_attrs) { %w[proof_of_ownership receive_notifications timezone date_stolen estimated_value].map(&:to_sym) }
          include_context :geocoder_real
          it "updates and returns to the right page" do
            # VCR for some reason fails to match this request with standard matching, so specify different
            VCR.use_cassette("bikes_controller-create-stolen", match_requests_on: [:path]) do
              expect(stolen_record.date_stolen).to be_present
              expect(stolen_record.proof_of_ownership).to be_falsey
              expect(stolen_record.receive_notifications).to be_truthy

              bike.reload
              expect(bike.current_stolen_record).to eq stolen_record
              expect(bike.stolen).to be_truthy

              put :update, params: { id: bike.id, bike: bike_attrs, edit_template: "fancy_template" }
              expect(flash[:error]).to_not be_present
              expect(response).to redirect_to edit_bike_url(page: "fancy_template")
              bike.reload
              expect(bike.stolen).to be_truthy

              # Stupid cheat because we're creating an extra record here for fuck all reason
              current_stolen_record = bike.fetch_current_stolen_record
              expect(bike.stolen_records.count).to eq 1
              expect(bike.fetch_current_stolen_record.id).to eq stolen_record.id
              # stolen_record.reload
              expect(bike.fetch_current_stolen_record.id).to eq stolen_record.id
              expect(current_stolen_record.date_stolen.to_i).to be_within(1).of target_time
              expect(current_stolen_record.proof_of_ownership).to be_truthy
              expect(current_stolen_record.receive_notifications).to be_falsey
              expect(current_stolen_record.estimated_value).to eq 1200
              stolen_attrs.except(*skipped_attrs).each do |key, value|
                pp key unless current_stolen_record.send(key) == value
                expect(current_stolen_record.send(key)).to eq value
              end
            end
          end
          context "canadian stolen record" do
            let!(:canada) { FactoryBot.create(:country, name: "Canada", iso: "CA") }
            let(:stolen_attrs) do
              {
                date_stolen: "2016-02-08 04:00:00",
                timezone: "America/Chicago",
                phone: "9999999999",
                street: "2222 Cambridge St.",
                country_id: canada.id,
                city: "Vancouver",
                zipcode: "V5L1E6",
                state_id: state.id,
                locking_description: "I locked it up!",
                lock_defeat_description: "",
                theft_description: "I deeply care about this bike, nefariousness!",
                police_report_number: "#666",
                police_report_department: "Vancouver",
                secondary_phone: "8888888888",
                proof_of_ownership: 1,
                receive_notifications: 0,
                estimated_value: "5200",
              }
            end
            it "updates, ignores passed state" do
              VCR.use_cassette("bikes_controller-create-stolen-canada", match_requests_on: [:path]) do
                expect(stolen_record.date_stolen).to be_present
                bike.reload

                expect(bike.fetch_current_stolen_record).to eq stolen_record
                put :update, params: { id: bike.id, bike: bike_attrs, edit_template: "fancy_template" }
                expect(flash[:error]).to_not be_present
                expect(response).to redirect_to edit_bike_url(page: "fancy_template")
                bike.reload
                expect(bike.stolen).to be_truthy
                # Stupid cheat because we're creating an extra record here for fuck all reason
                current_stolen_record = bike.fetch_current_stolen_record
                expect(bike.stolen_records.count).to eq 1
                expect(bike.fetch_current_stolen_record.id).to eq stolen_record.id

                expect(bike.fetch_current_stolen_record.id).to eq stolen_record.id
                expect(current_stolen_record.date_stolen.to_i).to be_within(1).of target_time
                expect(current_stolen_record.proof_of_ownership).to be_truthy
                expect(current_stolen_record.receive_notifications).to be_falsey
                expect(current_stolen_record.estimated_value).to eq 5200
                expect(current_stolen_record.state_id).to be_blank # Ensure we don't do this accidentally, like we were
                expect(current_stolen_record.to_coordinates).to eq([49.1573024, -123.9664322])
                stolen_attrs.except(:state_id, *skipped_attrs).each do |key, value|
                  pp key unless current_stolen_record.send(key) == value
                  expect(current_stolen_record.send(key)).to eq value
                end
              end
            end
          end
          context "recovered bike" do
            it "marks the bike recovered"
          end
        end
      end
    end
    context "owner present (who is allowed to edit)" do
      let(:user) { FactoryBot.create(:user_confirmed) }
      let(:ownership) { FactoryBot.create(:ownership_organization_bike, owner_email: user.email) }
      let(:bike) { ownership.bike }
      let(:organization) { bike.organizations.first }
      let(:organization_2) { FactoryBot.create(:organization) }
      let(:allowed_attributes) do
        {
          description: "69 description",
          marked_user_hidden: "0",
          primary_frame_color_id: color.id,
          secondary_frame_color_id: color.id,
          tertiary_frame_color_id: Color.black.id,
          handlebar_type: "other",
          coaster_brake: true,
          belt_drive: true,
          front_gear_type_id: FactoryBot.create(:front_gear_type).id,
          rear_gear_type_id: FactoryBot.create(:rear_gear_type).id,
          owner_email: "new_email@stuff.com",
          year: 1993,
          frame_model: "A sweet model named things",
          frame_size: "56cm",
          name: "a sweet name for a bike",
          extra_registration_number: "some weird other number",
          bike_organization_ids: "#{organization_2.id}, #{organization.id}",
        }
      end
      let(:skipped_attrs) { %w[marked_user_hidden bike_organization_ids].map(&:to_sym) }
      before do
        ownership.mark_claimed
        set_current_user(user)
        expect(ownership.owner).to eq user
      end
      it "updates the bike with the allowed_attributes" do
        put :update, params: { id: bike.id, bike: allowed_attributes, organization_ids_can_edit_claimed: [organization_2.id] }
        expect(response).to redirect_to edit_bike_url(bike)
        expect(assigns(:bike)).to be_decorated
        bike.reload
        expect(bike.hidden).to be_falsey
        allowed_attributes.except(*skipped_attrs).each do |key, value|
          pp value, key unless bike.send(key) == value
          expect(bike.send(key)).to eq value
        end
        expect(bike.bike_organization_ids).to match_array([organization.id, organization_2.id])
        expect(bike.editable_organizations.pluck(:id)).to eq([organization_2.id])
      end

      # There is no way to encode an empty array using an HTML form (e.g. Content-Type: url-form-encoded).
      # See: https://github.com/rails/rails/issues/27215#issuecomment-263972010
      context "empty organization_ids_can_edit_claimed", skip: "TODO: ensure use case is validated" do
        it "updates the bike with the allowed_attributes, marks no organizations can edit claimed" do
          put :update,
              params: {
                id: bike.id,
                bike: allowed_attributes,
                organization_ids_can_edit_claimed: [],
              }
          expect(response).to redirect_to edit_bike_url(bike)
          expect(assigns(:bike)).to be_decorated
          bike.reload
          expect(bike.hidden).to be_falsey
          allowed_attributes.except(*skipped_attrs).each do |key, value|
            pp value, key unless bike.send(key) == value
            expect(bike.send(key)).to eq value
          end
          expect(bike.bike_organization_ids).to match_array([organization.id, organization_2.id])
          expect(bike.editable_organizations.pluck(:id)).to eq([])
        end
      end

      context "organization_ids_can_edit_claimed_present" do
        it "updates the bike with the allowed_attributes, marks no organizations can edit claimed" do
          put :update, params: { id: bike.id, bike: allowed_attributes, organization_ids_can_edit_claimed_present: "1" }
          expect(response).to redirect_to edit_bike_url(bike)
          expect(assigns(:bike)).to be_decorated
          bike.reload
          expect(bike.hidden).to be_falsey
          allowed_attributes.except(*skipped_attrs).each do |key, value|
            pp value, key unless bike.send(key) == value
            expect(bike.send(key)).to eq value
          end
          expect(bike.bike_organization_ids).to match_array([organization.id, organization_2.id])
          expect(bike.editable_organizations.pluck(:id)).to eq([])
        end
      end
    end
    context "organized bike, member present" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:can_edit_claimed) { false }
      let(:claimed) { false }
      let(:bike) { FactoryBot.create(:bike_organized, :with_ownership, organization: organization, can_edit_claimed: can_edit_claimed, claimed: claimed) }
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      before { set_current_user(user) }
      it "updates the bike" do
        bike.reload
        expect(bike.owner).to_not eq(user)
        expect(bike.editable_organizations.pluck(:id)).to eq([organization.id])
        expect(bike.authorized_by_organization?(u: user)).to be_truthy
        put :update, params: { id: bike.id, bike: { description: "new description", handlebar_type: "forward" } }
        expect(response).to redirect_to edit_bike_url(bike)
        expect(assigns(:bike)).to be_decorated
        bike.reload
        expect(bike.hidden).to be_falsey
        expect(bike.description).to eq "new description"
        expect(bike.handlebar_type).to eq "forward"
        expect(bike.editable_organizations.pluck(:id)).to eq([organization.id])
      end
      context "bike is claimed" do
        let(:claimed) { true }
        it "fails to update" do
          bike.reload
          expect(bike.owner).to_not eq(user)
          expect(bike.editable_organizations.pluck(:id)).to eq([])
          expect(bike.authorized_by_organization?(u: user)).to be_falsey
          put :update, params: { id: bike.id, bike: { description: "new description", handlebar_type: "forward" } }
          expect(flash[:error]).to be_present
          expect(assigns(:bike)).to be_present
          expect(bike.description).to_not eq "new description"
        end
        context "can_edit_claimed true" do
          let(:can_edit_claimed) { true }
          it "updates the bike" do
            bike.reload
            expect(bike.owner).to_not eq(user)
            expect(bike.editable_organizations.pluck(:id)).to eq([organization.id])
            expect(bike.authorized_by_organization?(u: user)).to be_truthy
            put :update, params: { id: bike.id, bike: { description: "new description", handlebar_type: "forward" } }
            expect(response).to redirect_to edit_bike_url(bike)
            expect(assigns(:bike)).to be_present
            bike.reload
            expect(bike.hidden).to be_falsey
            expect(bike.description).to eq "new description"
            expect(bike.handlebar_type).to eq "forward"
          end
        end
      end
    end
  end

  describe "show with recovery token present" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let(:stolen_record) { bike.current_stolen_record }
    let(:recovery_link_token) { stolen_record.find_or_create_recovery_link_token }
    it "renders a mark recovered modal, and deletes the session recovery_link_token" do
      session[:recovery_link_token] = recovery_link_token
      get :show, params: { id: bike.id }
      expect(response.body).to match(recovery_link_token)
      expect(session[:recovery_link_token]).to be_nil
    end
  end
end
