# frozen_string_literal: true

require "rails_helper"

# Verifies the impound records index browser behavior: results load into a
# turbo-frame, the dropdown/location filters drive it, and the multi-update
# flow (`org--impound-update-multi` + `org--impound-update`) reacts to the
# rendered DOM. Lives at the integration layer because the controllers react
# to the rendered DOM.
RSpec.describe "Organized impound records index", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[parking_notifications impound_bikes]) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:base_url) { "/o/#{organization.to_param}/impound_records" }

  # `created_at: 2.hours.ago` keeps `calculated_unregistered_bike?` from
  # auto-flagging the registered record as unregistered (it does so for any
  # impound on a bike created within the last hour).
  let!(:registered) { FactoryBot.create(:impound_record_with_organization, organization:, user:, created_at: 2.hours.ago) }
  let!(:unregistered) { FactoryBot.create(:impound_record_with_organization, organization:, user:, created_at: 2.hours.ago, unregistered_bike: true) }
  # Both are impounded "now" from fixed addresses; only the NYC one falls
  # inside the stubbed New York bounding box.
  let!(:impounded_nyc) do
    FactoryBot.create(:impound_record_with_organization, organization:, user:, created_at: 2.hours.ago,
      display_id_integer: 9001,
      impounded_from_address_record: FactoryBot.create(:address_record, :new_york, kind: :impounded_from))
  end
  let!(:impounded_la) do
    FactoryBot.create(:impound_record_with_organization, organization:, user:, created_at: 2.hours.ago,
      display_id_integer: 9002,
      impounded_from_address_record: FactoryBot.create(:address_record, :los_angeles, kind: :impounded_from))
  end
  include_context :geocoder_default_location
  include_context :geocoder_stubbed_bounding_box

  def checkbox_for(impound_record)
    find("input[type=checkbox][name='ids[#{impound_record.id}]']", visible: :all)
  end

  def check_for_update(impound_record)
    expect(checkbox_for(impound_record)).not_to be_disabled
    # The error alert collapsing open above the table shifts this row down for a
    # moment, so a check dispatched mid-animation lands at the old spot and
    # misses. `check` is idempotent, so retry until it registers -- like a user
    # clicking again -- bounded by Capybara's wait time.
    deadline = Time.current + Capybara.default_max_wait_time
    loop do
      check "ids[#{impound_record.id}]"
      break if checkbox_for(impound_record).checked? || Time.current > deadline
    end
    expect(checkbox_for(impound_record)).to be_checked
  end

  before do
    page.current_window.resize_to(1280, 900)
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    find(".alert-success .close").click
    # Wait for the dismissed flash to finish fading out — otherwise the
    # fixed-position alert can intercept the org submenu/nav clicks below.
    # The Bootstrap fade-out can exceed Capybara's default 2s wait on slow CI.
    expect(page).to have_no_css(".alert-success", wait: 10)
    find("#passive_organization_submenu").click
    within(".current-organization-submenu") { click_link "Impounded Bikes" }
    expect(page).to have_current_path(/\A#{Regexp.escape(base_url)}(\?|\z)/, wait: 10)
  end

  it "loads results via turbo, filters by unregisteredness, then applies multi-updates" do
    # Results load into the turbo-frame via the search--form auto-submit
    expect(page).to have_css("turbo-frame#impound_records_results_frame table tbody tr", count: 4, wait: 10)
    # search_no_js should NOT be in the URL (removed by the JS controller)
    expect(page).not_to have_current_path(/search_no_js/)

    # Unregisteredness dropdown link advances the URL (data-turbo-action="advance")
    # and updates the frame in place
    within("turbo-frame#impound_records_results_frame") do
      all("[data-ui--dropdown-target='button']").last.click
    end
    click_link "Only unregistered"

    expect(page).to have_current_path(/search_unregisteredness=only_unregistered/, wait: 10)
    expect(page).to have_css("turbo-frame#impound_records_results_frame table tbody tr", count: 1)

    # Back navigation restores the unfiltered listing (the search--form
    # controller re-points the results frame at the restored URL on popstate).
    page.go_back
    expect(page).not_to have_current_path(/search_unregisteredness/, wait: 10)
    expect(page).to have_css("turbo-frame#impound_records_results_frame table tbody tr", count: 4, wait: 10)

    # Search form submit + direct back-nav: regression guard for the stale
    # turbo-frame state the no-cache meta prevents. The form submit updates the
    # frame via turbo_stream; back-nav must restore it fresh from the server,
    # not from a cached snapshot (whose frame the popstate fix can't recover).
    fill_in "search_email", with: "nobody@example.com"
    find("#search-button").click

    expect(page).to have_current_path(/search_email=nobody/, wait: 10)
    expect(page).to have_css("turbo-frame#impound_records_results_frame", wait: 10)
    expect(page).to have_no_css("turbo-frame#impound_records_results_frame table tbody tr")

    page.go_back
    expect(page).not_to have_current_path(/search_email=nobody/, wait: 10)
    expect(page).to have_css("turbo-frame#impound_records_results_frame table tbody tr", count: 4, wait: 10)
    # The form input DOM value survives back-nav (browser form-state restore),
    # so clear it before the next search or it would silently re-filter.
    fill_in "search_email", with: ""

    registered_kinds = checkbox_for(registered)["data-update-kinds"].split
    unregistered_kinds = checkbox_for(unregistered)["data-update-kinds"].split

    # Every record allows note/removed_from_bike_index/transferred_to_new_owner;
    # only the registered bike allows retrieved_by_owner.
    expect(registered_kinds).to include("note", "removed_from_bike_index", "transferred_to_new_owner", "retrieved_by_owner")
    expect(unregistered_kinds).to include("note", "removed_from_bike_index", "transferred_to_new_owner")
    expect(unregistered_kinds).not_to include("retrieved_by_owner")

    # The proximity + location fields submit with the search form via turbo
    fill_in "search_proximity", with: "50"
    fill_in "search_location", with: "New York"
    find("#search-button").click

    expect(page).to have_current_path(/search_location=New\+York/, wait: 10)
    expect(page).to have_current_path(/search_proximity=50/)

    # Only the NYC-impounded record is inside the bounding box; the
    # locationless registered/unregistered records and the LA one drop out.
    within("turbo-frame#impound_records_results_frame") do
      expect(page).to have_css("table tbody tr", count: 1)
      expect(page).to have_content("9001")
      expect(page).not_to have_content("9002")
    end
    page.go_back

    # Back navigation restores the unfiltered listing (all 4 rows)
    expect(page).to have_css("turbo-frame#impound_records_results_frame table tbody tr", count: 4, wait: 10)

    # Cells are hidden until the user opts into multi-update.
    expect(page).not_to have_css("input[type=checkbox][name='ids[#{registered.id}]']", visible: true)

    click_button "update multiple records"

    # Wait for the makeMultiUpdate panel to be expanded — the kind <select> is
    # inside it, so its visibility is the signal the Stimulus controller has run.
    expect(page).to have_select("impound_record_update_kind", visible: true, wait: 10)
    expect(page).to have_css("input[type=checkbox][name='ids[#{registered.id}]']", visible: true)
    # Opening reflects in the URL (via replaceState — no new history entry)
    expect(page).to have_current_path(/multi_update=true/)

    # Default kind retrieved_by_owner: unregistered's checkbox is disabled
    # (its bike is flagged unregistered, so retrieved_by_owner doesn't apply).
    expect(checkbox_for(unregistered)).to be_disabled

    # Submitting with nothing checked shows an error and doesn't submit
    within("#impoundRecordUpdateForm") { find("input[type=submit]").click }
    expect(page).to have_css("[role=alert]", text: /select at least one record/i)
    expect(unregistered.impound_record_updates).to be_empty

    # Checking a row hides the error again
    check_for_update(registered)
    expect(page).to have_no_css("[role=alert]", text: /select at least one record/i)
    within("#impoundRecordUpdateForm") { find("input[type=submit]").click }

    expect(page).to have_content("Updated 1 impound record", wait: 10)
    expect(registered.impound_record_updates.pluck(:kind)).to eq ["retrieved_by_owner"]
    expect(unregistered.impound_record_updates).to be_empty

    # redirect_back keeps multi_update=true, so the index reloads with the
    # panel server-rendered open — the toggle now reads "hide update".
    expect(page).to have_current_path(/multi_update=true/)
    expect(page).to have_select("impound_record_update_kind", visible: true, wait: 5)

    # "hide update" collapses the panel; clicking the toggle again reopens it
    click_button "hide update"
    expect(page).to have_select("impound_record_update_kind", visible: :hidden, wait: 5)
    expect(page).not_to have_current_path(/multi_update=true/)
    click_button "update multiple records"
    expect(page).to have_select("impound_record_update_kind", visible: true, wait: 5)
    # registered is resolved now, so the three remaining active rows stay
    expect(page).to have_css("table tbody tr", count: 3)
    expect(page).to have_css("input[type=checkbox][name='ids[#{unregistered.id}]']", visible: true)

    # Switch to a kind every remaining record allows (note), so Toggle-all
    # checks all three. org--impound-update reveals the field for the selected
    # kind and disables it while hidden so the required transfer_email doesn't
    # block other kinds.
    expect(page).to have_field("impound_record_update[transfer_email]", visible: :hidden, disabled: true)
    select "Transferred To Owner", from: "impound_record_update_kind"
    expect(page).to have_field("impound_record_update[transfer_email]", visible: true, disabled: false)
    select "Add Internal Note", from: "impound_record_update_kind"
    expect(page).to have_field("impound_record_update[transfer_email]", visible: :hidden, disabled: true)

    # Select-all checks every enabled row — all three remaining records here
    click_button "Toggle all checked"
    expect(checkbox_for(unregistered)).to be_checked
    expect(checkbox_for(impounded_nyc)).to be_checked
    expect(checkbox_for(impounded_la)).to be_checked
    fill_in "impound_record_update[notes]", with: "multi-update note"
    within("#impoundRecordUpdateForm") { find("input[type=submit]").click }

    expect(page).to have_content("Updated 3 impound record", wait: 10)
    [unregistered, impounded_nyc, impounded_la].each do |record|
      last_update = record.impound_record_updates.reorder(:id).last
      expect(last_update.kind).to eq "note"
      expect(last_update.notes).to eq "multi-update note"
    end
  end
end
