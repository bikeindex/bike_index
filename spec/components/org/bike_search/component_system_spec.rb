# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::BikeSearch::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/org/bike_search/component/default" }
  let!(:organization) { FactoryBot.create(:organization_hogwarts) }
  let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }

  before do
    visit(preview_path)
    page.execute_script("localStorage.removeItem('orgBikeColumns'); localStorage.removeItem('orgBikeSettingsOpen')")
    visit("about:blank")
    visit(preview_path)
    expect(page).to have_css("[data-controller='org--bike-search']", wait: 5)
  end

  it "toggles settings panel visibility" do
    settings_selector = "[data-org--bike-search-target='settings']"
    # Close settings if initially open (can happen on CI due to timing)
    click_link "settings" if page.has_css?(settings_selector, visible: true, wait: 1)
    expect(page).not_to have_css(settings_selector, visible: true, wait: 2)

    click_link "settings"
    expect(page).to have_css(settings_selector, visible: true, wait: 2)

    click_link "settings"
    expect(page).not_to have_css(settings_selector, visible: true, wait: 2)
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
    click_link "settings"
    check "url_cell"

    expect(page).to have_css("th.url_cell", visible: true)

    # Uncheck it
    uncheck "url_cell"
    expect(page).to have_css("th.url_cell", visible: :hidden)
  end

  it "persists column selection in localStorage" do
    # Open settings and check URL column
    click_link "settings"
    check "url_cell"

    stored = page.evaluate_script("localStorage.getItem('orgBikeColumns')")
    columns = JSON.parse(stored)
    expect(columns).to include("url_cell")

    # Reload and verify persistence
    page.refresh
    expect(page).to have_css("th.url_cell", visible: true, wait: 5)
  end
end
