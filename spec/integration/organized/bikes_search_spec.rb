# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized bikes search", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[bike_search]) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:bikes_path) { "/o/#{organization.to_param}/bikes" }

  let!(:bike1) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: "alice@example.com") }
  let!(:bike2) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: "bob@example.com") }

  before do
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
  end

  it "searches by email" do
    visit bikes_path
    expect(page).to have_css("table.table", wait: 10)
    expect(page).to have_css("tbody tr", minimum: 2)

    fill_in "search_email", with: "alice@example.com"
    find("#search-button").click

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)
    expect(page).to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")

    # submits when enter is pressed twice
    visit bikes_path
    expect(page).to have_css("table.table", wait: 10)

    fill_in "search_email", with: "alice@example.com"
    find("#search_email").send_keys(:return)

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)
  end

  context "with avery_export enabled" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[bike_search avery_export]) }
    let!(:avery_bike) do
      bike = FactoryBot.create(:bike_organized, :with_address_record, creation_organization: organization)
      bike.current_ownership.update!(owner_name: "Test Owner")
      bike
    end

    it "toggles avery export column via checkbox" do
      visit bikes_path
      expect(page).to have_css("table.table", wait: 10)
      expect(page).not_to have_css("th.avery_cell")

      # Open settings and check avery — triggers page reload with param
      click_link "settings"
      check "avery_cell"
      expect(page).to have_current_path(/search_avery_export=true/, wait: 10)
      # Avery column should be visible with check mark for exportable bike
      expect(page).to have_css("th.avery_cell", visible: true)
      expect(page).to have_css("td.avery_cell", text: "✓")

      # Settings panel is already open (persisted via localStorage)
      # Uncheck avery — triggers page reload without param
      expect(page).to have_field("avery_cell", checked: true, wait: 5)
      uncheck "avery_cell"
      expect(page).not_to have_current_path(/search_avery_export/, wait: 10)
      expect(page).not_to have_css("th.avery_cell")
    end
  end
end
