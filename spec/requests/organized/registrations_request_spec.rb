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
        # Bracketed, since a cold request can take seconds
        range_before = UI::PeriodSelect::Component.period_range(period)
        get base_url, params: {search_no_js: true, period:}
        range_after = UI::PeriodSelect::Component.period_range(period)
        expect(assigns(:start_time)).to be_between(range_before.first, range_after.first)
        expect(assigns(:end_time)).to be_between(range_before.last, range_after.last)
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
    describe "location search" do
      include_context :geocoder_stubbed_bounding_box
      let(:enabled_feature_slugs) { %w[bike_search reg_address] }
      let!(:bike) { FactoryBot.create(:bike_organized, :with_address_record, creation_organization: current_organization) }
      let!(:bike_chicago) do
        FactoryBot.create(:bike_organized, :with_address_record, address_in: :chicago, creation_organization: current_organization)
      end
      let!(:stolen_bike) do
        bike = FactoryBot.create(:bike_organized, creation_organization: current_organization)
        FactoryBot.create(:stolen_record, :in_nyc, bike:)
        bike
      end

      it "searches within the distance of the location" do
        get base_url, params: {search_no_js: true, location: "New York", distance: "50"}
        expect(response.status).to eq(200)
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id, stolen_bike.id])
        expect(response.body).to include("show_location_search")

        get base_url, params: {search_no_js: true, location: "", distance: "50"}
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id, bike_chicago.id, stolen_bike.id])

        get base_url, params: {search_no_js: true, location: ["New York"], distance: ["50"]}
        expect(response.status).to eq(200)
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id, bike_chicago.id, stolen_bike.id])

        # Searching all, it's only searched alongside a stolen or impounded status
        get base_url, params: {search_no_js: true, location: "New York", distance: "50", search_all: true}
        expect(assigns(:bikes).pluck(:id)).to include(bike.id, bike_chicago.id, stolen_bike.id)
        expect(response.body).to include("You can&#39;t search location when searching all registrations")

        get base_url, params: {search_no_js: true, location: "New York", distance: "50", search_all: true, search_status: "stolen"}
        expect(assigns(:bikes).pluck(:id)).to eq([stolen_bike.id])
      end
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
            location: "", distance: "100", sort: "id", sort_direction: "desc", create_export: true
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
    it "renders the cards view" do
      get base_url, params: {search_no_js: true, search_result_view: "cards"}
      expect(response.status).to eq(200)
      expect(response.body).to include(bike.mnfg_name)
      expect(response.body).to_not include("Column settings")
      expect(response.body).to include("Ordered by Registered, descending")
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

      it "compares the year scope with the year before only once the organization is a year old" do
        get base_url, headers: frame_headers
        expect(assigns(:registrations_stats).map(&:previous_count)).to eq [nil, nil, nil]

        Rails.cache.clear
        current_organization.update_column(:created_at, 13.months.ago)
        get base_url, headers: frame_headers
        expect(assigns(:registrations_stats).map(&:previous_count)).to eq [0, 0, 0]
      end
    end

    context "search_result_view" do
      it "defaults to the table, and carries what it's given into the next search" do
        get base_url, params: {search_no_js: true}
        expect(assigns(:result_view)).to eq :table

        get base_url, params: {search_no_js: true, search_result_view: "nonsense"}
        expect(assigns(:result_view)).to eq :table

        get base_url, params: {search_no_js: true, search_result_view: "cards"}
        expect(assigns(:result_view)).to eq :cards
        # The view rides in the address bar, so a new search has to carry it
        expect(Capybara.string(response.body))
          .to have_css("#Search_Form input[name=search_result_view][value=cards]", visible: :all)
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
      let(:enabled_feature_slugs) { %w[bike_search registration_sequences show_partial_registrations] }
      let(:registration_sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization: current_organization) }
      let!(:bike_acknowledged_earlier) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }
      let!(:bike_acknowledged_later) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }
      before do
        FactoryBot.create(:registration_sequence_acknowledgment, registration_sequence:, bike: bike_acknowledged_earlier, acknowledged_at: 2.days.ago)
        FactoryBot.create(:registration_sequence_acknowledgment, registration_sequence:, bike: bike_acknowledged_later, acknowledged_at: 1.day.ago)
        # Another organization's acknowledgment doesn't count
        FactoryBot.create(:registration_sequence_acknowledgment, bike:)
      end

      def sorted_bike_ids(direction)
        get base_url, params: {search_no_js: true, sort: "acknowledged_at", direction:}
        assigns(:bikes).map(&:id)
      end

      it "sorts by when this organization's sequence was acknowledged, a register flow bike once its rules are agreed to" do
        expect(sorted_bike_ids("desc")).to eq([bike.id, bike_acknowledged_later.id, bike_acknowledged_earlier.id])
        expect(sorted_bike_ids("asc")).to eq([bike_acknowledged_earlier.id, bike_acknowledged_later.id, bike.id])

        get "/register/new", params: {organization_id: current_organization.to_param}
        b_param = BParam.last
        post "/register", params: {b_param_token: b_param.id_token,
                                   b_param: {manufacturer_id: FactoryBot.create(:manufacturer).id, cycle_type: "e-scooter",
                                             owner_email: "owner@example.com"}}
        get "/o/#{current_organization.to_param}/bikes/incompletes"
        expect(assigns(:b_params)).to eq([b_param])

        # Step 2 creates the bike ahead of the safety rules - registered, not incomplete
        patch "/register", params: {b_param_token: b_param.id_token,
                                    bike: {primary_frame_color_id: FactoryBot.create(:color).id, serial_number: "XYZ 123",
                                           status: "status_with_owner", user_name: "Sally Rider"}}
        registered_bike = Bike.find(b_param.reload.created_bike_id)
        expect(registered_bike.unfinished_registration?).to be_truthy

        get "/o/#{current_organization.to_param}/bikes/incompletes"
        expect(assigns(:b_params)).to eq([])

        expect(sorted_bike_ids("desc").first(2)).to match_array([bike.id, registered_bike.id])
        expect(sorted_bike_ids("asc").last(2)).to match_array([bike.id, registered_bike.id])

        registration_sequence.registration_sequence_pages.each_with_index do |page, index|
          patch "/register/acknowledge", params: {b_param_token: b_param.id_token, registration_sequence_id: registration_sequence.id,
                                                  step: (index + 3).to_s, acknowledged: page.bullets.each_index.to_h { [it.to_s, "1"] }}
        end
        patch "/register/acknowledge", params: {b_param_token: b_param.id_token, registration_sequence_id: registration_sequence.id,
                                                step: "review", acknowledged_all: "1"}
        expect(registered_bike.unfinished_registration?).to be_falsey

        expect(sorted_bike_ids("desc")).to eq([bike.id, registered_bike.id, bike_acknowledged_later.id, bike_acknowledged_earlier.id])
        expect(sorted_bike_ids("asc")).to eq([bike_acknowledged_earlier.id, bike_acknowledged_later.id, registered_bike.id, bike.id])
      end
    end

    context "sorted by status at" do
      let!(:stolen_bike) { FactoryBot.create(:bike_organized, :with_stolen_record, creation_organization: current_organization, date_stolen: 3.days.ago) }

      it "sorts by occurred_at" do
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

    context "the switches below the legacy one" do
      # Both submit together, so what's checked is the whole setting
      def set_switches(**params)
        post "#{base_url}/switches", params: params
        expect(response).to redirect_to "#{base_url}/new"
        get "#{base_url}/new"
      end

      def form_field_names(scope)
        Nokogiri::HTML(response.body).css("form[action='/register'] [name^='#{scope}[']").map { |n| n["name"] }.uniq
      end

      it "asks for both steps on one page, and stops once it's unchecked" do
        get "#{base_url}/new"
        expect(form_field_names("bike")).to eq([])

        set_switches(single_page: true)
        expect(session[:register_settings]).to include("single_page" => true)
        expect(form_field_names("b_param")).to include "b_param[owner_email]"
        expect(form_field_names("bike")).to include "bike[serial_number]"

        # The preference follows the session rather than the link that set it
        get "#{base_url}/new"
        expect(form_field_names("bike")).to include "bike[serial_number]"

        set_switches
        expect(session[:register_settings]).to include("single_page" => false)
        expect(form_field_names("bike")).to eq([])
      end

      it "stores the separate attestation switch" do
        set_switches(separate_attestation: true)
        expect(session[:register_settings]).to include("separate_attestation" => true)

        set_switches(single_page: true)
        expect(session[:register_settings]).to include("separate_attestation" => false)
      end
    end

    context "both steps on one page" do
      let!(:sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization: current_organization) }
      let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Trek") }
      let(:color) { FactoryBot.create(:color, name: "Red") }

      # The one page submits both steps together, so the whole registration is this post
      def register_e_scooter
        post "#{base_url}/switches", params: {single_page: true}
        get "#{base_url}/new"
        b_param = BParam.last
        post "/register", params: {b_param_token: b_param.id_token, single_page: true,
                                   propulsion_type_motorized: true,
                                   b_param: {manufacturer_id: "Trek", cycle_type: "e-scooter", owner_email: "customer@example.com"},
                                   bike: {primary_frame_color_id: color.id, serial_number: "XYZ 123",
                                          status: "status_with_owner", user_name: "Sally Rider"}}
        b_param.reload
      end

      def motorized_text
        Nokogiri::HTML(response.body).at_css("[data-register--status-fields-target=submitLabel]")["data-motorized-text"]
      end

      it "labels the submit for the safety pages an e-vehicle would get, without a progress count yet" do
        post "#{base_url}/switches", params: {single_page: true}
        get "#{base_url}/new"
        expect(motorized_text).to eq "Next"
        expect(Nokogiri::HTML(response.body).css("span.tw\\:h-1.tw\\:rounded-full")).to be_empty

        # Left to the registrant, so an e-vehicle registered here finishes on this page
        post "#{base_url}/switches", params: {single_page: true, separate_attestation: true}
        get "#{base_url}/new"
        expect(motorized_text).to be_blank
      end

      # The submission is what makes it an e-vehicle, so the sequence isn't knowable
      # until it's saved - and nothing after this post resolves it again
      it "stops at the safety pages, which the submission is what asks for" do
        b_param = nil
        expect { b_param = register_e_scooter }
          .to change(Bike, :count).by(1).and change(RegistrationSequenceAcknowledgment.pending, :count).by 1
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: "3")
      end
    end

    context "the registrant fills out the attestation separately" do
      let!(:sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization: current_organization) }
      let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Trek") }
      let(:color) { FactoryBot.create(:color, name: "Red") }
      let(:owner_email) { "customer@example.com" }
      let(:details) do
        {primary_frame_color_id: color.id, serial_number: "XYZ 123",
         status: "status_with_owner", user_name: "Sally Rider"}
      end

      # Through the flow rather than the service, since the switch is a session preference
      def register_e_scooter
        post "#{base_url}/switches", params: {separate_attestation: true}
        get "#{base_url}/new"
        b_param = BParam.last
        post "/register", params: {b_param_token: b_param.id_token, propulsion_type_motorized: true,
                                   b_param: {manufacturer_id: "Trek", cycle_type: "e-scooter", owner_email:}}
        patch "/register", params: {b_param_token: b_param.id_token, bike: details}
        b_param.reload
      end

      it "finishes the member's registration off step 2, and sends the owner the safety rules to agree to" do
        b_param = nil
        expect { b_param = register_e_scooter }
          .to change(Bike, :count).by(1).and change(RegistrationSequenceAcknowledgment.pending, :count).by 1
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: "finished")
        expect(Bike.last).to have_attributes(owner_email:, cycle_type: "e-scooter")
        expect(Bike.last.current_ownership.registration_info.slice("register_single_page", "register_separate_attestation"))
          .to eq("register_separate_attestation" => true)
        # The owner's to agree to, so nothing is left to alert the member who registered it
        expect(b_param.unfinished_registration?(current_user)).to be_falsey
        follow_redirect!
        expect(response.body).to include "the safety rules to agree to"

        # The claim email waits on the rules, and the rules email is what goes out
        expect { EmailJobs::OwnershipInvitationJob.drain }.to_not change(ActionMailer::Base.deliveries, :count)
        expect { EmailJobs::PartialRegistrationJob.drain }.to change(ActionMailer::Base.deliveries, :count).by 1
        expect(ActionMailer::Base.deliveries.last.to).to eq([owner_email])
        expect(ActionMailer::Base.deliveries.last.body.encoded).to include "Agree to the safety rules"

        log_in(FactoryBot.create(:user_confirmed, email: owner_email))
        get "/register", params: {b_param_token: b_param.id_token}
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: "3")
        %w[3 4].each do |step|
          patch acknowledge_register_path, params: {b_param_token: b_param.id_token, registration_sequence_id: sequence.id,
                                                    step:, acknowledged: {"0" => "1", "1" => "1"}}
        end
        expect {
          patch acknowledge_register_path, params: {b_param_token: b_param.id_token, registration_sequence_id: sequence.id,
                                                    step: "review", acknowledged_all: "1"}
        }.to change(RegistrationSequenceAcknowledgment.acknowledged, :count).by 1
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: "finished")
        expect(RegistrationSequenceAcknowledgment.sole.user.email).to eq owner_email
        expect { EmailJobs::OwnershipInvitationJob.drain }.to change(ActionMailer::Base.deliveries, :count).by 1
      end

      context "registering their own" do
        let(:owner_email) { current_user.email }

        it "asks for the attestation, which is theirs to agree to" do
          b_param = nil
          expect { b_param = register_e_scooter }
            .to change(Bike, :count).by(1).and change(RegistrationSequenceAcknowledgment.pending, :count).by 1
          expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: "3")
        end
      end

      context "a bike, which has no safety pages to leave out" do
        it "doesn't count as a separate attestation" do
          post "#{base_url}/switches", params: {separate_attestation: true}
          get "#{base_url}/new"
          b_param = BParam.last
          post "/register", params: {b_param_token: b_param.id_token,
                                     b_param: {manufacturer_id: "Trek", cycle_type: "bike", owner_email:}}
          expect { patch "/register", params: {b_param_token: b_param.id_token, bike: details} }
            .to change(Bike, :count).by 1
          expect(Bike.last.current_ownership.registration_info.keys).to_not include "register_separate_attestation"
        end
      end

      context "registering for another organization" do
        let(:other_organization) { FactoryBot.create(:organization) }
        let!(:other_sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization: other_organization) }

        it "asks for its attestation - the switch is this organization's" do
          post "#{base_url}/switches", params: {separate_attestation: true}
          get "/register/new", params: {organization_id: other_organization.id}
          b_param = BParam.last
          expect(b_param.creation_organization_id).to eq other_organization.id
          post "/register", params: {b_param_token: b_param.id_token, propulsion_type_motorized: true,
                                     b_param: {manufacturer_id: "Trek", cycle_type: "e-scooter", owner_email:}}
          expect { patch "/register", params: {b_param_token: b_param.id_token, bike: details} }
            .to change(Bike, :count).by(1).and change(RegistrationSequenceAcknowledgment.pending, :count).by 1
          expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: "3")
        end
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
