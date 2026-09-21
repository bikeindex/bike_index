require "rails_helper"

RSpec.describe Organized::RegistrationsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/registrations" }
  include_context :request_spec_logged_in_as_organization_user
  let(:enabled_feature_slugs) { %w[bike_search show_recoveries show_partial_registrations bike_stickers impound_bikes] }
  let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: enabled_feature_slugs) }

  describe "index" do
    # UI::PeriodSelect's chips fill the custom panel from their own ranges, so they have to
    # be the ranges the controller computes for the same period
    it "computes the ranges the period chips carry" do
      %w[hour day week month year].each do |period|
        get base_url, params: {search_no_js: true, period:}
        range = UI::PeriodSelect::Component.period_range(period)
        expect(assigns(:start_time)).to be_within(5.seconds).of(range.first)
        expect(assigns(:end_time)).to be_within(5.seconds).of(range.last)
      end
    end

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
      # impound_bikes is enabled, so registrations leave impounded bikes out unless asked
      expect(assigns(:search_status)).to eq "not_impounded"
      expect(assigns(:bikes).pluck(:id)).to eq([])
      expect(assigns(:search_stickers)).to eq false
      # create_export fails if the org doesn't have have csv_exports
      expect {
        get base_url, params: query_params.merge(create_export: true)
      }.to_not change(Export, :count)
      # Search without_street to verify that scope works

      get base_url, params: {search_no_js: true, search_address: "without_street"}
      expect(response.status).to eq(200)
      expect(assigns(:bikes).pluck(:id)).to eq([bike.id])
    end
    context "member_no_bike_edit" do
      let(:current_user) { FactoryBot.create(:organization_user, organization: current_organization, role: "member_no_bike_edit") }
      it "allows viewing" do
        expect(current_user.reload.organization_roles.first.role).to eq "member_no_bike_edit"
        get base_url, params: query_params
        expect(response.status).to eq(200)
        expect(assigns(:current_organization)).to eq current_organization
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
          expect(flash[:notice]).to be_present
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
    context "with search_all" do
      it "reaches past the organization's own registrations, and refuses an export" do
        get base_url, params: {search_no_js: true}
        expect(assigns(:bikes).pluck(:id)).to eq([bike.id])

        get base_url, params: {search_no_js: true, search_all: true}
        expect(response.status).to eq(200)
        expect(assigns(:search_all)).to be_truthy
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id, non_organization_bike.id])
      end

      it "counts and pages only as far as the card counts" do
        FactoryBot.create(:bike_organized, creation_organization: current_organization)
        stub_const("BikeServices::OrganizedSearch::SEARCH_ALL_COUNT_LIMIT", 1)

        get base_url, params: {search_no_js: true, search_all: true, per_page: 1}
        expect(assigns(:pagy).count).to eq 1
        expect(assigns(:pagy).last).to eq 1

        # The organization's own registrations are countable, so they aren't capped
        get base_url, params: {search_no_js: true, per_page: 1}
        expect(assigns(:pagy).count).to eq 2
        expect(assigns(:pagy).last).to eq 2
      end

      context "with search_email" do
        let!(:non_organization_bike) { FactoryBot.create(:bike, owner_email: bike.owner_email) }

        it "only searches the organization's registrations" do
          get base_url, params: {search_no_js: true, search_all: true, search_email: bike.owner_email}
          expect(response.status).to eq(200)
          expect(assigns(:search_all)).to be_falsey
          expect(assigns(:bikes).pluck(:id)).to eq([bike.id])
        end
      end

      context "with csv_exports" do
        let(:enabled_feature_slugs) { %w[bike_search csv_exports] }

        it "doesn't create an export" do
          expect {
            get base_url, params: {search_no_js: true, search_all: true, create_export: true, serial: bike.serial_number}
          }.to_not change(Export, :count)
          expect(response.status).to eq(200)
        end
      end
    end

    context "with search_unregisteredness" do
      let!(:unregistered_bike) do
        FactoryBot.create(:bike_organized, creation_organization: current_organization,
          status: "unregistered_parking_notification")
      end

      it "filters on the bike's own status" do
        get base_url, params: {search_no_js: true, search_unregisteredness: "only_unregistered"}
        expect(response.status).to eq(200)
        expect(assigns(:search_unregisteredness)).to eq "only_unregistered"
        expect(assigns(:bikes).pluck(:id)).to eq([unregistered_bike.id])

        get base_url, params: {search_no_js: true, search_unregisteredness: "only_registered"}
        expect(assigns(:bikes).pluck(:id)).to eq([bike.id])

        # and an unrecognized value doesn't filter
        get base_url, params: {search_no_js: true, search_unregisteredness: "whatever"}
        expect(assigns(:search_unregisteredness)).to eq false
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id, unregistered_bike.id])

        # nor does a malformed one
        get base_url, params: {search_no_js: true, search_unregisteredness: ["only_unregistered"]}
        expect(response.status).to eq(200)
        expect(assigns(:search_unregisteredness)).to eq false
      end
    end

    context "the chart frame asking" do
      let(:frame_headers) { {"Turbo-Frame" => "chart_card_frame"} }

      it "answers the year scope unless asked for the search, linking both at the page's URL" do
        get base_url, params: {serial: "no-match-at-all"}, headers: frame_headers
        expect(response.status).to eq(200)
        expect(assigns(:chart_scope)).to eq "year"

        get base_url, params: {chart_scope: "search"}, headers: frame_headers
        expect(response.status).to eq(200)
        expect(assigns(:chart_scope)).to eq "search"

        # The scope links advance the address bar, so what they put there has to be the page
        get base_url, params: {period: "week"}, headers: frame_headers
        expect(assigns(:chart_scope_paths)[:year]).to eq "#{base_url}?chart_scope=year&period=week"

        # Sorting is a different question than which scope the chart is answering
        get base_url, params: {search_no_js: true, chart_scope: "year"}
        expect(assigns(:sort_state).search_params[:chart_scope]).to eq "year"
      end

      it "counts whole months for the year scope, and holds them for the hour" do
        get base_url, headers: frame_headers
        expect(assigns(:chart_time_range).first).to eq(Time.current.beginning_of_month - 1.year)
        expect(assigns(:registrations_stats).first.count).to eq 1

        FactoryBot.create(:bike_organized, creation_organization: current_organization)
        get base_url, headers: frame_headers
        expect(assigns(:registrations_stats).first.count).to eq 1

        # The searched scope answers the search as it is, so it isn't held
        get base_url, params: {chart_scope: "search"}, headers: frame_headers
        expect(assigns(:registrations_stats).first.count).to eq 2

        # ...but only ever over the organization's own, whatever search_all asks
        get base_url, params: {chart_scope: "search", search_all: true}, headers: frame_headers
        expect(assigns(:registrations_stats).first.count).to eq 2
      end
    end

    context "search_result_view" do
      it "defaults to the spreadsheet, and carries what it's given into the next search" do
        get base_url, params: {search_no_js: true}
        expect(assigns(:result_view)).to eq :spreadsheet

        get base_url, params: {search_no_js: true, search_result_view: "nonsense"}
        expect(assigns(:result_view)).to eq :spreadsheet

        get base_url, params: {search_no_js: true, search_result_view: "thumbnail"}
        expect(assigns(:result_view)).to eq :thumbnail
        # The view rides in the address bar, so a new search has to carry it
        expect(Capybara.string(response.body))
          .to have_css("#Search_Form input[name=search_result_view][value=thumbnail]", visible: :all)
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
        expect(current_organization.reload.is_invoiced?).to be_truthy
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
        expect(assigns(:search_stickers)).to eq false
        # Without impound_bikes there's no impoundedness to leave out
        expect(assigns(:search_status)).to eq "all"
        expect(assigns(:interpreted_params)[:stolenness]).to eq "all"
        expect(assigns(:interpreted_params)).to match_hash_indifferently({stolenness: "all"})

        # ... and no filtering by it either, the panel doesn't offer the impound statuses
        get base_url, params: {search_no_js: true, search_status: "impounded"}
        expect(assigns(:search_status)).to eq "all"
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id, bike_with_sticker.id, impounded_bike.id])
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

    context "organization without an invoice" do
      let(:current_organization) { FactoryBot.create(:organization) }

      it "renders without search" do
        expect(impounded_bike.reload.status).to eq "status_impounded"
        expect(current_organization.reload.is_invoiced?).to be_falsey
        expect(Bike).to_not receive(:search)
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id, impounded_bike.id])
      end
    end

    context "sorted by registration sequence acknowledgment" do
      let(:enabled_feature_slugs) { %w[bike_search registration_sequences] }
      let(:registration_sequence) { FactoryBot.create(:registration_sequence_active, organization: current_organization) }
      let!(:bike_acknowledged_earlier) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }
      let!(:bike_acknowledged_later) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }
      before do
        FactoryBot.create(:registration_sequence_acknowledgment, registration_sequence:, bike: bike_acknowledged_earlier, created_at: 2.days.ago)
        FactoryBot.create(:registration_sequence_acknowledgment, registration_sequence:, bike: bike_acknowledged_later, created_at: 1.day.ago)
        # Another organization's acknowledgment doesn't count
        FactoryBot.create(:registration_sequence_acknowledgment, bike:)
      end

      it "sorts by when this organization's sequence was acknowledged" do
        get base_url, params: {search_no_js: true, sort: "acknowledged_at", direction: "desc"}
        expect(assigns(:bikes).map(&:id)).to eq([bike.id, bike_acknowledged_later.id, bike_acknowledged_earlier.id])

        get base_url, params: {search_no_js: true, sort: "acknowledged_at", direction: "asc"}
        expect(assigns(:bikes).map(&:id)).to eq([bike_acknowledged_earlier.id, bike_acknowledged_later.id, bike.id])
      end
    end

    context "sorted by status at" do
      let!(:stolen_bike) { FactoryBot.create(:bike_organized, :with_stolen_record, creation_organization: current_organization, date_stolen: 3.days.ago) }

      it "sorts by occurred_at, with the registrations that have none last either way" do
        impounded_bike
        expect(bike.reload.occurred_at).to be_nil
        expect(stolen_bike.reload.occurred_at).to be < impounded_bike.reload.occurred_at

        get base_url, params: {search_no_js: true, search_status: "all", sort: "occurred_at", direction: "desc"}
        expect(assigns(:bikes).map(&:id)).to eq([impounded_bike.id, stolen_bike.id, bike.id])

        get base_url, params: {search_no_js: true, search_status: "all", sort: "occurred_at", direction: "asc"}
        expect(assigns(:bikes).map(&:id)).to eq([stolen_bike.id, impounded_bike.id, bike.id])
      end
    end

    context "with search_notes" do
      let(:enabled_feature_slugs) { %w[bike_search registration_notes] }
      let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }

      before { FactoryBot.create(:bike_organization_note, bike:, body: "important note") }

      it "filters by notes, and carries the terms back into the form" do
        get base_url, params: {search_no_js: true, search_notes: "important", search_email: bike.owner_email}
        expect(response.status).to eq(200)
        expect(assigns(:bikes).pluck(:id)).to eq([bike.id])
        body = Capybara.string(response.body)
        expect(body).to have_css("input[name='search_notes'][value='important']")
        expect(body).to have_css("input[name='search_email'][value='#{bike.owner_email}']")

        get base_url, params: {search_no_js: true, search_notes: "nonexistent"}
        expect(response.status).to eq(200)
        expect(assigns(:bikes).pluck(:id)).to eq([])
      end
    end
    context "claimed_ownerships without bike_search" do
      let(:enabled_feature_slugs) { %w[claimed_ownerships] }

      it "renders the claimedness dropdown defaulting to all, and filters by it" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:search_claimedness)).to eq "all"
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id])

        get base_url, params: {search_claimedness: "initial"}
        expect(response.status).to eq(200)
        expect(assigns(:search_claimedness)).to eq "initial"
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id])
      end
    end
    context "bike_stickers without bike_search" do
      let(:enabled_feature_slugs) { %w[bike_stickers] }
      let!(:claimed_sticker) { FactoryBot.create(:bike_sticker_claimed, organization: current_organization, bike:) }
      let(:unclaimed_sticker) { FactoryBot.create(:bike_sticker, organization: current_organization) }

      it "renders the sticker columns" do
        get base_url, params: {bike_sticker: unclaimed_sticker.code}
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:bike_sticker)).to eq unclaimed_sticker
        expect(assigns(:bikes).pluck(:id)).to eq([bike.id])
        expect(response.body).to include(claimed_sticker.pretty_code)
        expect(response.body).to include(CGI.escapeHTML(bike_sticker_path(id: unclaimed_sticker.code, organization_id: current_organization.id, bike_id: bike.id)))
      end
    end
    context "unsupported format" do
      it "returns 406 for json" do
        get "#{base_url}.json", params: {period: "custom", start_time: "2025-04-01", end_time: "2026-04-30", per_page: "1"}
        expect(response.status).to eq(406)
      end
    end
  end

  describe "new" do
    it "renders the register flow's step 1, attributed to the organization, inside the organized menu" do
      expect { get "#{base_url}/new" }.to change(BParam, :count).by 1
      expect(response.status).to eq(200)
      b_param = BParam.last
      expect(b_param).to have_attributes(origin: "register_flow_organized",
        creation_organization_id: current_organization.id)
      expect(assigns(:b_param)&.id).to eq b_param.id
      # The member is registering someone else's vehicle, so it isn't seeded with their email
      expect(b_param.owner_email).to be_blank
      expect(response.body).to include("org_sidebar_nav")
      expect(response.body).to include(b_param.id_token)
      expect(response.body).to include(new_organization_bike_path(organization_id: current_organization.to_param))

      expect { get "#{base_url}/new" }.to_not change(BParam, :count)

      # ... but a shell started on /register isn't taken over, so it stays attributed there
      expect { get "/register/new?discard_token=#{b_param.id_token}" }.to_not change(BParam, :count)
      expect(BParam.last.origin).to eq "register_flow"
      expect { get "#{base_url}/new" }.to change(BParam, :count).by 1
      b_param = BParam.last
      expect(b_param.origin).to eq "register_flow_organized"

      # A link naming a status or an owner seeds the shell it lands on, rather than
      # starting another one
      expect { get "#{base_url}/new", params: {status: "stolen"} }.to_not change(BParam, :count)
      expect { get "#{base_url}/new", params: {email: "customer@bikeindex.org"} }
        .to_not change(BParam, :count)
      expect(b_param.reload).to have_attributes(status: "status_stolen",
        owner_email: "customer@bikeindex.org")
    end

    context "gone back to the old view" do
      # bikes#new redirects without one, so the old view has to be reachable
      let(:current_organization) do
        FactoryBot.create(:organization_with_organization_features, :with_auto_user, enabled_feature_slugs:)
      end
      let(:old_view_path) { new_organization_bike_path(organization_id: current_organization.to_param) }
      # Not a let - it's read after each request in turn, and a let would memoize the first
      def menu_add_bike_path
        Nokogiri::HTML(response.body).css("#org_sidebar_nav a")
          .find { |a| a.text.strip == "Add a bike" }&.[]("href")
      end

      it "keeps the menu on the old view until the register flow is asked for again" do
        get "#{base_url}/new"
        expect(menu_add_bike_path).to eq "#{base_url}/new"

        get old_view_path, params: {old_view: true}
        expect(session[:old_register_view]).to be_truthy
        expect(menu_add_bike_path).to eq old_view_path

        # Every organized page follows it, not just the one that set it
        get base_url
        expect(menu_add_bike_path).to eq old_view_path

        # And the register flow's own link is the way back
        get "#{base_url}/new"
        expect(session[:old_register_view]).to be_blank
        expect(menu_add_bike_path).to eq "#{base_url}/new"

        # Landing on the old view any other way isn't a preference
        get old_view_path
        expect(session[:old_register_view]).to be_blank
        expect(menu_add_bike_path).to eq "#{base_url}/new"
      end
    end

    context "not an organization member" do
      include_context :request_spec_logged_in_as_user

      it "redirects" do
        expect { get "#{base_url}/new" }.to_not change(BParam, :count)
        expect(response).to redirect_to user_root_url
      end
    end
  end

  describe "multi_search" do
    it "renders" do
      get "#{base_url}/multi_search"
      expect(response.status).to eq(200)
      expect(response).to render_template :multi_search
    end

    it "wires up multi-search, the column settings and its collapse on one element" do
      get "#{base_url}/multi_search"
      wrapper = Nokogiri::HTML(response.body).at_css("[data-org--multi-search-url-value]")
      expect(wrapper["data-controller"].split).to match_array(%w[org--multi-search ui--collapse org--search org--search-column-settings])
      expect(JSON.parse(wrapper["data-org--search-column-settings-default-columns-value"])).to include("created_at_cell")
    end
  end

  describe "multi_search_response" do
    let!(:bike) { FactoryBot.create(:bike_organized, serial_number: "ABCD1234", creation_organization: current_organization) }
    let!(:other_bike) { FactoryBot.create(:bike, serial_number: "WXYZ9999") }

    it "returns matching org bikes, and none from other orgs" do
      get "#{base_url}/multi_search_response", params: {serial: "ABCD1234"},
        headers: {"Accept" => "text/vnd.turbo-stream.html"}
      expect(response.status).to eq(200)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(assigns(:bikes).pluck(:id)).to eq([bike.id])

      get "#{base_url}/multi_search_response", params: {serial: "WXYZ9999"},
        headers: {"Accept" => "text/vnd.turbo-stream.html"}
      expect(response.status).to eq(200)
      expect(assigns(:bikes)).to be_empty
    end

    context "with search_all" do
      let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html"} }

      it "widens results across orgs, redacting non-org data and leaving org bikes intact" do
        # Other-org bike: returned, with private fields redacted
        get "#{base_url}/multi_search_response", params: {serial: "WXYZ9999", search_all: "1"}, headers: turbo_headers
        expect(response.status).to eq(200)
        expect(assigns(:search_all)).to eq true
        expect(assigns(:bikes).pluck(:id)).to eq([other_bike.id])
        expect(response.body).to include("Hidden because it is not registered with #{current_organization.short_name}")
        expect(response.body).not_to include(other_bike.owner_email)

        # Own-org bike: full data renders, no redaction marker
        get "#{base_url}/multi_search_response", params: {serial: "ABCD1234", search_all: "1"}, headers: turbo_headers
        expect(assigns(:bikes).pluck(:id)).to eq([bike.id])
        expect(response.body).to include(bike.owner_email)
        expect(response.body).not_to include("Hidden because it is not registered")
      end
    end

    context "without serial param" do
      it "returns bad request" do
        get "#{base_url}/multi_search_response",
          headers: {"Accept" => "text/vnd.turbo-stream.html"}
        expect(response.status).to eq(400)
      end
    end
  end

  describe "multi_search_response (sticker search)" do
    let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html"} }
    let(:bike) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }
    let(:other_bike) { FactoryBot.create(:bike) }
    let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, code: "CA112", organization: current_organization, bike:) }
    let!(:unclaimed_sticker) { FactoryBot.create(:bike_sticker, code: "CA113", organization: current_organization) }
    let!(:other_sticker) { FactoryBot.create(:bike_sticker_claimed, code: "ZZ999", bike: other_bike) }

    it "returns claimed-sticker bikes (own + cross-org with redaction), skips unclaimed, 400s or blanks on a bad query" do
      # Own-org claimed sticker → bike returned
      get "#{base_url}/multi_search_response", params: {search_kind: "stickers", query: "CA112"}, headers: turbo_headers
      expect(response.status).to eq(200)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(assigns(:bikes).pluck(:id)).to eq([bike.id])

      # Unclaimed sticker → no bike
      get "#{base_url}/multi_search_response", params: {search_kind: "stickers", query: "CA113"}, headers: turbo_headers
      expect(response.status).to eq(200)
      expect(assigns(:bikes)).to be_empty

      # Cross-org claimed sticker → bike surfaces, private fields redacted
      get "#{base_url}/multi_search_response", params: {search_kind: "stickers", query: "ZZ999"}, headers: turbo_headers
      expect(response.status).to eq(200)
      expect(assigns(:bikes).pluck(:id)).to eq([other_bike.id])
      expect(response.body).to include("Hidden because it is not registered with #{current_organization.short_name}")
      expect(response.body).not_to include(other_bike.owner_email)

      # Missing query → bad request
      get "#{base_url}/multi_search_response", params: {search_kind: "stickers"}, headers: turbo_headers
      expect(response.status).to eq(400)

      # bike and other_bike both have claimed stickers; a query that normalizes to a blank code
      # must not fall through to sticker_code_search's `all` and surface every organization's bikes
      get "#{base_url}/multi_search_response", params: {search_kind: "stickers", query: "bikeindex.org/bikes/"}, headers: turbo_headers
      expect(response.status).to eq(200)
      expect(assigns(:bikes)).to be_empty
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

    it "redirects the user, blanking passive_organization_id" do
      get base_url
      expect(response).to redirect_to my_account_url
      expect(flash[:error]).to be_present
      # zero rather than nil, so we don't look it up again
      expect(session[:passive_organization_id]).to eq "0"
    end

    context "superuser" do
      include_context :request_spec_logged_in_as_superuser

      it "renders, assigning the organization" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:passive_organization)).to eq current_organization
        expect(assigns(:page_id)).to eq "organized_registrations_index"
        expect(session[:passive_organization_id]).to eq current_organization.id
      end
    end
  end
end
