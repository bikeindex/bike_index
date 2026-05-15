# frozen_string_literal: true

require "rails_helper"

# Verifies the multi-update behavior wired up in application.js: the per-row
# `canupdate-<kind>` classes drive which checkboxes get enabled/disabled when
# the kind dropdown changes. Lives at the integration layer because the JS
# selectors target `.multiselect-cell.canupdate-X input` on the rendered
# `<td>`s, so the Org::ImpoundRecordsTable component has to keep those classes
# on the cell elements themselves (not on a wrapper).
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

  def cell_for(impound_record)
    checkbox_for(impound_record).find(:xpath, "ancestor::td[1]", visible: :all)
  end

  before do
    # The "update multiple records" link is in .col-lg-3.hidden-md-down, so a
    # viewport >= lg (992px) is required for the multiselect flow to be reachable.
    page.current_window.resize_to(1280, 900)
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    find(".alert-success .close").click
    find("#passive_organization_submenu").click
    within(".current-organization-submenu") { click_link "Impounded Bikes" }
    expect(page).to have_current_path(/\A#{Regexp.escape(base_url)}(\?|\z)/, wait: 10)
  end

  it "renders per-row canupdate classes and toggles checkbox state as the kind changes" do
    expect(page).to have_css("table tbody tr", count: 2, wait: 10)

    registered_cell = cell_for(registered)
    unregistered_cell = cell_for(unregistered)

    # Every record allows note/removed_from_bike_index/transferred_to_new_owner;
    # only the registered bike allows retrieved_by_owner.
    %w[note removed_from_bike_index transferred_to_new_owner].each do |kind|
      expect(registered_cell[:class]).to include("canupdate-#{kind}")
      expect(unregistered_cell[:class]).to include("canupdate-#{kind}")
    end
    expect(registered_cell[:class]).to include("canupdate-retrieved_by_owner")
    expect(unregistered_cell[:class]).not_to include("canupdate-retrieved_by_owner")

    # Cells are hidden until the user opts into multi-update.
    expect(page).not_to have_css("input[type=checkbox][name='ids[#{registered.id}]']", visible: true)

    click_link "update multiple records"

    expect(page).to have_css("input[type=checkbox][name='ids[#{registered.id}]']", visible: true, wait: 5)
    expect(page).to have_css("input[type=checkbox][name='ids[#{unregistered.id}]']", visible: true)

    # Default kind is retrieved_by_owner: registered enabled, unregistered disabled.
    expect(checkbox_for(registered)).not_to be_disabled
    expect(checkbox_for(unregistered)).to be_disabled

    # Switching to a kind every record allows enables both.
    select "Add Internal Note", from: "impound_record_update_kind"
    expect(checkbox_for(unregistered)).not_to be_disabled
    expect(checkbox_for(registered)).not_to be_disabled

    checkbox_for(registered).check
    checkbox_for(unregistered).check

    # Switching back to retrieved_by_owner re-disables unregistered and clears
    # its checked state, while leaving registered's checked state alone.
    select "Owner Retrieved Bike", from: "impound_record_update_kind"
    expect(checkbox_for(unregistered)).to be_disabled
    expect(checkbox_for(unregistered)).not_to be_checked
    expect(checkbox_for(registered)).to be_checked
  end
end
