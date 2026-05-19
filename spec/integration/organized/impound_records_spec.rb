# frozen_string_literal: true

require "rails_helper"

# Verifies the impound multi-update behavior: `org--impound-update-multi` reads
# the per-row `data-update-kinds` off each checkbox to enable/disable them when
# the kind dropdown changes, and `org--impound-update` reveals the field for
# the selected kind. Lives at the integration layer because both controllers
# react to the rendered DOM.
RSpec.describe "Organized impound records multi-update", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[parking_notifications impound_bikes]) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:base_url) { "/o/#{organization.to_param}/impound_records" }

  # `created_at: 2.hours.ago` keeps `calculated_unregistered_bike?` from
  # auto-flagging the registered record as unregistered (it does so for any
  # impound on a bike created within the last hour).
  let!(:registered) { FactoryBot.create(:impound_record_with_organization, organization:, user:, created_at: 2.hours.ago) }
  let!(:unregistered) { FactoryBot.create(:impound_record_with_organization, organization:, user:, created_at: 2.hours.ago, unregistered_bike: true) }

  def checkbox_for(impound_record)
    find("input[type=checkbox][name='ids[#{impound_record.id}]']", visible: :all)
  end

  # Headless Chrome on CI sometimes loses the click on these freshly-enabled
  # checkboxes (set/check/native.click all flaked), so set the property
  # directly (and fire change, as a real click would). The form posts the
  # value regardless of how the box got checked.
  def check_for_update(impound_record)
    expect(checkbox_for(impound_record)).not_to be_disabled
    page.execute_script(<<~JS)
      const el = document.getElementById('ids_#{impound_record.id}')
      el.checked = true
      el.dispatchEvent(new Event('change', {bubbles: true}))
    JS
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
    expect(page).to have_no_css(".alert-success")
    find("#passive_organization_submenu").click
    within(".current-organization-submenu") { click_link "Impounded Bikes" }
    expect(page).to have_current_path(/\A#{Regexp.escape(base_url)}(\?|\z)/, wait: 10)
  end

  it "renders per-row update kinds and applies multi-updates for matching records" do
    expect(page).to have_css("table tbody tr", count: 2, wait: 10)

    registered_kinds = checkbox_for(registered)["data-update-kinds"].split
    unregistered_kinds = checkbox_for(unregistered)["data-update-kinds"].split

    # Every record allows note/removed_from_bike_index/transferred_to_new_owner;
    # only the registered bike allows retrieved_by_owner.
    expect(registered_kinds).to include("note", "removed_from_bike_index", "transferred_to_new_owner", "retrieved_by_owner")
    expect(unregistered_kinds).to include("note", "removed_from_bike_index", "transferred_to_new_owner")
    expect(unregistered_kinds).not_to include("retrieved_by_owner")

    # Cells are hidden until the user opts into multi-update.
    expect(page).not_to have_css("input[type=checkbox][name='ids[#{registered.id}]']", visible: true)

    click_button "update multiple records"

    # Wait for the makeMultiUpdate panel to be expanded — the kind <select> is
    # inside it, so its visibility is the signal the Stimulus controller has run.
    expect(page).to have_select("impound_record_update_kind", visible: true, wait: 5)
    expect(page).to have_css("input[type=checkbox][name='ids[#{registered.id}]']", visible: true)
    # Opening reflects in the URL (via replaceState — no new history entry)
    expect(page).to have_current_path(/multi_update=true/)

    # Default kind retrieved_by_owner: only registered's checkbox is enabled.
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
    # registered is resolved now, so only the unregistered row remains
    expect(page).to have_css("table tbody tr", count: 1)
    expect(page).to have_css("input[type=checkbox][name='ids[#{unregistered.id}]']", visible: true)

    # Now apply a note update to the unregistered record — a kind it allows.
    # org--impound-update reveals the field for the selected kind, and disables
    # it while hidden so the required transfer_email doesn't block other kinds.
    expect(page).to have_field("impound_record_update[transfer_email]", visible: :hidden, disabled: true)
    select "Transferred To Owner", from: "impound_record_update_kind"
    expect(page).to have_field("impound_record_update[transfer_email]", visible: true, disabled: false)
    select "Add Internal Note", from: "impound_record_update_kind"
    expect(page).to have_field("impound_record_update[transfer_email]", visible: :hidden, disabled: true)

    # Select-all checks every enabled row — just the unregistered one here
    click_button "Toggle all checked"
    expect(checkbox_for(unregistered)).to be_checked
    fill_in "impound_record_update[notes]", with: "multi-update note"
    within("#impoundRecordUpdateForm") { find("input[type=submit]").click }

    expect(page).to have_content("Updated 1 impound record", wait: 10)
    last_update = unregistered.impound_record_updates.reorder(:id).last
    expect(last_update.kind).to eq "note"
    expect(last_update.notes).to eq "multi-update note"
  end
end
