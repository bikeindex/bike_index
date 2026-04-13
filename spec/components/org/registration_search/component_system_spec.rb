# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::RegistrationSearch::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/org/registration_search/component/default" }
  let!(:organization) { FactoryBot.create(:organization_hogwarts) }
  let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }

  before do
    visit(preview_path)
    page.execute_script("localStorage.removeItem('orgRegistrationColumns'); localStorage.setItem('orgRegistrationSettingsOpen', 'false')")
    visit(preview_path)
    expect(page).to have_css("[data-controller~='org--registration-search']", wait: 5)
  end

  it "toggles settings panel visibility" do
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)
    settings_selector = "[data-org--registration-search-target='settings']"
    expect(page).not_to have_css(settings_selector, visible: true, wait: 2)

    click_button "settings"
    expect(page).to have_css(settings_selector, visible: true, wait: 5)
    sleep 0.3 # wait for show animation to complete before toggling again

    click_button "settings"
    expect(page).not_to have_css(settings_selector, visible: true, wait: 5)
  end

  it "checks default columns on connect" do
    # Default checked columns should be visible
    expect(page).to have_css("th.created_at_cell", visible: true)
    expect(page).to have_css("th.manufacturer_cell", visible: true)
    expect(page).to have_css("th.model_cell", visible: true)

    # Non-default columns should be hidden
    expect(page).to have_css("th.url_cell", visible: :hidden)
    expect(page).to have_css("th.updated_at_cell", visible: :hidden)
  end

  it "toggles column visibility when checkbox is clicked" do
    expect(page).to have_css("th.url_cell", visible: :hidden)

    # Open settings and check the URL column
    click_button "settings"
    check "url_cell"

    expect(page).to have_css("th.url_cell", visible: true)

    # Uncheck it
    uncheck "url_cell"
    expect(page).to have_css("th.url_cell", visible: :hidden)
  end

  it "persists column selection in localStorage" do
    # Open settings and check URL column
    click_button "settings"
    check "url_cell"

    # Wait for the JS change handler to update the column visibility before reading localStorage
    expect(page).to have_css("th.url_cell", visible: true, wait: 5)

    stored = page.evaluate_script("localStorage.getItem('orgRegistrationColumns')")
    columns = JSON.parse(stored)
    expect(columns).to include("url_cell")

    # Reload and verify persistence
    page.refresh
    expect(page).to have_css("th.url_cell", visible: true, wait: 5)
  end
end
