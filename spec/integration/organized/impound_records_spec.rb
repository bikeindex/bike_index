# frozen_string_literal: true

require "rails_helper"

# Verifies the impound multi-update behavior: `org--impound-update-multi` reads
# the per-row `canupdate-<kind>` classes off each checkbox to enable/disable
# them when the kind dropdown changes, and `org--impound-update` reveals the
# field for the selected kind. Lives at the integration layer because both
# controllers react to the rendered DOM.
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
  # directly. The form posts the value regardless of how the box got checked.
  def check_for_update(impound_record)
    expect(checkbox_for(impound_record)).not_to be_disabled
    page.execute_script("document.getElementById('ids_#{impound_record.id}').checked = true")
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

  it "renders per-row canupdate classes and applies multi-updates for matching records" do
    expect(page).to have_css("table tbody tr", count: 2, wait: 10)

    registered_checkbox = checkbox_for(registered)
    unregistered_checkbox = checkbox_for(unregistered)

    # Every record allows note/removed_from_bike_index/transferred_to_new_owner;
    # only the registered bike allows retrieved_by_owner.
    %w[note removed_from_bike_index transferred_to_new_owner].each do |kind|
      expect(registered_checkbox[:class]).to include("canupdate-#{kind}")
      expect(unregistered_checkbox[:class]).to include("canupdate-#{kind}")
    end
    expect(registered_checkbox[:class]).to include("canupdate-retrieved_by_owner")
    expect(unregistered_checkbox[:class]).not_to include("canupdate-retrieved_by_owner")

    # Cells are hidden until the user opts into multi-update.
    expect(page).not_to have_css("input[type=checkbox][name='ids[#{registered.id}]']", visible: true)

    click_button "update multiple records"

    # Wait for the makeMultiUpdate panel to be expanded — the kind <select> is
    # inside it, so its visibility is the signal the Stimulus controller has run.
    expect(page).to have_select("impound_record_update_kind", visible: true, wait: 5)
    expect(page).to have_css("input[type=checkbox][name='ids[#{registered.id}]']", visible: true)

    # Default kind retrieved_by_owner: only registered's checkbox is enabled.
    expect(checkbox_for(unregistered)).to be_disabled

    check_for_update(registered)
    within("#impoundRecordUpdateForm") { find("input[type=submit]").click }

    expect(page).to have_content("Updated 1 impound record", wait: 10)
    expect(registered.impound_record_updates.pluck(:kind)).to eq ["retrieved_by_owner"]
    expect(unregistered.impound_record_updates).to be_empty

    # Now apply a note update to the unregistered record — a kind it allows.
    click_button "update multiple records"
    expect(page).to have_select("impound_record_update_kind", visible: true, wait: 5)

    # org--impound-update reveals the field for the selected kind
    expect(page).to have_field("impound_record_update[transfer_email]", visible: :hidden)
    select "Transferred To Owner", from: "impound_record_update_kind"
    expect(page).to have_field("impound_record_update[transfer_email]", visible: true)
    select "Add Internal Note", from: "impound_record_update_kind"
    expect(page).to have_field("impound_record_update[transfer_email]", visible: :hidden)

    check_for_update(unregistered)
    fill_in "impound_record_update[notes]", with: "multi-update note"
    within("#impoundRecordUpdateForm") { find("input[type=submit]").click }

    expect(page).to have_content("Updated 1 impound record", wait: 10)
    last_update = unregistered.impound_record_updates.reorder(:id).last
    expect(last_update.kind).to eq "note"
    expect(last_update.notes).to eq "multi-update note"
  end
end
