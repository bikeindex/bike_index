require "rails_helper"

RSpec.describe Organized::RegistrationsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/registrations" }
  include_context :request_spec_logged_in_as_organization_user
  let(:enabled_feature_slugs) { %w[bike_search show_recoveries show_partial_registrations bike_stickers impound_bikes] }
  let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: enabled_feature_slugs) }

  describe "index" do
    # NOTE: Additional index tests in controller spec because of session
    let(:query_params) do
      {
        search_no_js: true,
        query: "1",
        manufacturer: "2",
        colors: %w[3 4],
        location: "5",
        distance: "6",
        serial: "9",
        query_items: %w[7 8],
        stolenness: "stolen"
      }.as_json
    end
    let!(:non_organization_bike) { FactoryBot.create(:bike) }
    let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }
    let(:impounded_bike) { FactoryBot.create(:bike_organized, :impounded, creation_organization: current_organization) }
    it "sends all the params and renders search template to organization_bikes" do
      get base_url, params: query_params
      expect(response.status).to eq(200)
      expect(response.body).to_not include("fbevents.js")
      expect(assigns(:current_organization)).to eq current_organization
      expect(assigns(:search_query_present)).to be_truthy
      expect(assigns(:bikes).pluck(:id)).to eq([])
      expect(assigns(:search_stickers)).to eq false
      # create_export fails if the org doesn't have have csv_exports
      expect {
        get base_url, params: query_params.merge(create_export: true)
      }.to_not change(Export, :count)
      # Search without_street to verify that scope works

      get base_url, params: {search_no_js: true, search_address: "without_street"}
      expect(response.status).to eq(200)
      expect(assigns(:search_query_present)).to be_falsey
      expect(assigns(:bikes).pluck(:id)).to eq([bike.id])
    end
    context "member_no_bike_edit" do
      let(:current_user) { FactoryBot.create(:organization_user, organization: current_organization, role: "member_no_bike_edit") }
      it "allows viewing" do
        expect(current_user.reload.organization_roles.first.role).to eq "member_no_bike_edit"
        get base_url, params: query_params
        expect(response.status).to eq(200)
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:search_query_present)).to be_truthy
        expect(assigns(:bikes).pluck(:id)).to eq([])
      end
    end
    describe "create_export" do
      let(:enabled_feature_slugs) { %w[bike_search show_recoveries show_partial_registrations bike_stickers impound_bikes csv_exports] }
      let(:target_params) do
        {
          organization_id: current_organization.id,
          custom_bike_ids: "#{bike.id}_#{bike2.id}",
          only_custom_bike_ids: true
        }
      end
      let!(:bike2) { FactoryBot.create(:bike_organized, creation_organization: current_organization, manufacturer: bike.manufacturer) }
      it "creates export" do
        expect {
          get base_url, params: {manufacturer: bike.manufacturer.id, create_export: true}
        }.to change(Export, :count).by 0
        expect(flash).to be_blank
        redirected_to = response.redirect_url
        expect(redirected_to.gsub(/custom_bike_ids=\d+_\d+&/, "")).to eq new_organization_export_url(target_params.except(:custom_bike_ids))
        custom_bike_ids = redirected_to.match(/custom_bike_ids=(\d+)_(\d+)&/)[1, 2]
        expect(custom_bike_ids).to match_array([bike.id, bike2.id].map(&:to_s))

        expect {
          get base_url, params: {stolenness: "impounded", create_export: true}
        }.to change(Export, :count).by 0
        expect(flash[:error]).to match(/no match/)
        expect(response).to redirect_to(new_organization_export_url(organization_id: current_organization.id, only_custom_bike_ids: true, custom_bike_ids: ""))

        reset! # Clear stale flash from session cookie
        expect {
          get base_url, params: {search_stickers: "none", create_export: true}
        }.to change(Export, :count).by 0
        expect(flash).to be_blank
        redirected_to = response.redirect_url
        expect(redirected_to.gsub(/custom_bike_ids=\d+_\d+&/, "")).to eq new_organization_export_url(target_params.except(:custom_bike_ids))
        custom_bike_ids = redirected_to.match(/custom_bike_ids=(\d+)_(\d+)&/)[1, 2]
        expect(custom_bike_ids).to match_array([bike.id, bike2.id].map(&:to_s))
      end
      context "without search params" do
        let(:params_blank) do
          {
            period: nil, organization_id: current_organization.id, search_email: nil, serial: nil,
            end_time: nil, start_time: nil, user_id: nil, search_bike_id: nil, render_chart: false,
            search_marketplace_listing_id: nil, search_status: nil, search_kind: nil, search_ignored: nil,
            stolenness: "all", search_stickers: nil, search_address: nil, search_secondary: nil,
            sort: "id", sort_direction: "desc", create_export: true
          }
        end
        it "redirects to export new" do
          expect {
            get base_url, params: params_blank.merge(search_stickers: "all")
          }.to change(Export, :count).by 0
          expect(flash[:error]).to match(/no bikes selected/i)
          expect(response).to redirect_to new_organization_export_url(organization_id: current_organization.id)

          expect {
            get base_url, params: params_blank.merge(period: "year")
          }.to change(Export, :count).by 0
          expect(flash[:error]).to match(/no bikes selected/i)

          redirected_to = response.redirect_url
          expect(redirected_to.gsub(/end_at=\d+&?/, "").gsub(/start_at=\d+&?/, "").gsub(/\?\z/, ""))
            .to eq new_organization_export_url(organization_id: current_organization.id)

          start_at = redirected_to.match(/start_at=(\d+)/)[1]
          expect(start_at.to_i).to be_within(5).of((Time.current.beginning_of_day - 1.year).to_i)

          end_at = redirected_to.match(/end_at=(\d+)/)[1]
          expect(end_at.to_i).to be_within(5).of(Time.current.to_i)
        end
      end
      context "directly create export", :flaky do
        it "directly creates" do
          Sidekiq::Job.clear_all
          expect {
            get base_url, params: {manufacturer: bike.manufacturer.id, create_export: true, directly_create_export: 1}
          }.to change(Export, :count).by 1
          expect(flash[:info]).to be_present
          export = Export.last
          expect(export.organization_id).to eq current_organization.id
          expect(export.kind).to eq "organization"
          expect(export.custom_bike_ids).to match_array([bike.id, bike2.id])
          expect(export.user_id).to eq current_user.id
          expect(response).to redirect_to(organization_export_path(export, organization_id: current_organization.id))
          expect(OrganizationExportJob.jobs.count).to eq 1
        end
      end
    end
    context "turbo_stream" do
      it "renders with update action" do
        get base_url, as: :turbo_stream
        expect(response.media_type).to eq Mime[:turbo_stream].to_s
        expect(response).to have_http_status(:success)
        expect(response.body).to include("<turbo-stream action=\"update\" target=\"organized_bikes_results_frame\">")
        expect(response).to render_template(:index)
        expect(assigns(:bikes).pluck(:id)).to eq([bike.id])
      end
    end

    context "with search_stickers, no impounded feature" do
      let(:enabled_feature_slugs) { %w[bike_search show_recoveries show_partial_registrations bike_stickers] }
      let!(:bike_with_sticker) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, organization: current_organization, bike: bike_with_sticker) }
      let!(:bike_sticker_2) { FactoryBot.create(:bike_sticker_claimed, organization: current_organization, bike: non_organization_bike) }

      it "searches for bikes with stickers" do
        expect(impounded_bike.reload.status).to eq "status_impounded"
        expect(bike_with_sticker.reload.bike_sticker?).to be_truthy
        expect(current_organization.reload.paid?).to be_truthy
        get base_url, params: {search_no_js: true, search_stickers: "none"}
        expect(response.status).to eq(200)
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:search_stickers)).to eq "none"
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id, impounded_bike.id])
        expect(session[:passive_organization_id]).to eq current_organization.id

        # And searching without params returns expected result
        get base_url, params: {search_no_js: true}
        expect(response.status).to eq(200)
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id, bike_with_sticker.id, impounded_bike.id])
        expect(assigns(:search_query_present)).to be_falsey
        expect(assigns(:search_stickers)).to eq false
        expect(assigns(:interpreted_params)[:stolenness]).to eq "all"
        expect(assigns(:interpreted_params)).to match_hash_indifferently({stolenness: "all"})
      end
    end

    context "with caching" do
      around do |example|
        ActionController::Base.perform_caching = true
        ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
        example.run
      ensure
        ActionController::Base.perform_caching = false
        ActionController::Base.cache_store = :null_store
      end

      it "caches bike rows and busts cache when updated_at changes" do
        get base_url, params: {search_no_js: true}
        expect(response.status).to eq(200)
        expect(response.body).to include(bike.mnfg_name)

        bike.update_column(:frame_model, "ZZZ-CachedModel")

        # Same updated_at, so cached content should be served
        get base_url, params: {search_no_js: true}
        expect(response.body).not_to include("ZZZ-CachedModel")

        # Touch updated_at to bust cache
        bike.update_column(:updated_at, 1.second.from_now)

        get base_url, params: {search_no_js: true}
        expect(response.body).to include("ZZZ-CachedModel")
      end
    end

    context "unpaid organization" do
      let(:current_organization) { FactoryBot.create(:organization) }

      it "renders without search" do
        expect(impounded_bike.reload.status).to eq "status_impounded"
        expect(current_organization.reload.paid?).to be_falsey
        expect(Bike).to_not receive(:search)
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id, impounded_bike.id])
      end
    end

    context "with search_notes" do
      let(:enabled_feature_slugs) { %w[bike_search registration_notes] }
      let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }

      before { FactoryBot.create(:bike_organization_note, bike:, body: "important note") }

      it "filters by notes" do
        get base_url, params: {search_no_js: true, search_notes: "important"}
        expect(response.status).to eq(200)
        expect(assigns(:bikes).pluck(:id)).to eq([bike.id])

        get base_url, params: {search_no_js: true, search_notes: "nonexistent"}
        expect(response.status).to eq(200)
        expect(assigns(:bikes).pluck(:id)).to eq([])
      end
    end
  end

  describe "multi_search" do
    it "renders" do
      get "#{base_url}/multi_search"
      expect(response.status).to eq(200)
      expect(response).to render_template :multi_search
    end
  end

  describe "multi_search_response" do
    let!(:bike) { FactoryBot.create(:bike_organized, serial_number: "ABCD1234", creation_organization: current_organization) }
    let!(:other_bike) { FactoryBot.create(:bike, serial_number: "WXYZ9999") }

    it "searches and returns matching org bikes" do
      get "#{base_url}/multi_search_response", params: {serial: "ABCD1234"},
        headers: {"Accept" => "text/vnd.turbo-stream.html"}
      expect(response.status).to eq(200)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(assigns(:bikes).pluck(:id)).to eq([bike.id])
    end

    it "does not return bikes from other orgs" do
      get "#{base_url}/multi_search_response", params: {serial: "WXYZ9999"},
        headers: {"Accept" => "text/vnd.turbo-stream.html"}
      expect(response.status).to eq(200)
      expect(assigns(:bikes)).to be_empty
    end

    context "without serial param" do
      it "returns bad request" do
        get "#{base_url}/multi_search_response",
          headers: {"Accept" => "text/vnd.turbo-stream.html"}
        expect(response.status).to eq(400)
      end
    end
  end

  context "given an authenticated ambassador" do
    include_context :request_spec_logged_in_as_ambassador
    let(:base_url) { "/o/#{current_organization.to_param}/registrations" }

    describe "index" do
      it "redirects to the organization root path" do
        get base_url
        expect(response).to redirect_to(organization_root_path)
      end
    end

    describe "multi_search" do
      it "renders" do
        get "#{base_url}/multi_search"
        expect(response.status).to eq(200)
        expect(response).to render_template :multi_search
      end
    end

    describe "multi_search_response" do
      let!(:bike) { FactoryBot.create(:bike_organized, serial_number: "ABCD1234", creation_organization: current_organization) }

      it "searches and returns matching org bikes" do
        get "#{base_url}/multi_search_response", params: {serial: "ABCD1234"},
          headers: {"Accept" => "text/vnd.turbo-stream.html"}
        expect(response.status).to eq(200)
        expect(assigns(:bikes).pluck(:id)).to eq([bike.id])
      end
    end
  end

  context "not organization member" do
    include_context :request_spec_logged_in_as_user
    let!(:current_organization) { FactoryBot.create(:organization) }
    let(:base_url) { "/o/#{current_organization.to_param}/registrations" }

    it "redirects the user" do
      get base_url
      expect(response).to redirect_to my_account_url
      expect(flash[:error]).to be_present
    end
  end
end
