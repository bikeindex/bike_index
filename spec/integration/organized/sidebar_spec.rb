# frozen_string_literal: true

require "rails_helper"

# The sidebar's current row is UI::ActiveLink's, resolved in the browser, and the group
# holding it is opened from that — neither is visible to a component spec.
RSpec.describe "Organization sidebar", :js, type: :system do
  let(:organization) do
    FactoryBot.create(:organization_with_organization_features, :with_auto_user,
      enabled_feature_slugs: %w[impound_bikes parking_notifications bike_stickers])
  end
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:slug) { organization.to_param }

  before do
    # Above the sidebar's 1100px auto-collapse breakpoint, so it's the full column
    # rather than the icon rail, which hides every row's label
    page.current_window.resize_to(1280, 1600)
    using_wait_time(10) do
      visit new_session_path
      fill_in "Email", with: user.email
      click_button "Continue"
      fill_in "Password", with: "testthisthing7$"
      click_button "Log in"
      dismiss_flash_messages
    end
  end

  def expect_open(label)
    expect(page).to have_css("#org_sidebar_nav button[aria-expanded='true']", text: label)
  end

  it "opens the group holding the page, follows a row, and moves the current row with it" do
    visit "/o/#{slug}/impound_records"

    # The group holding the page is the one open; the others stay shut
    expect_open("Impounded Vehicles")
    expect(page).to have_css "#org_sidebar_nav a[aria-current]", text: "Search Impounded Vehicles"
    expect(page).to have_no_css "#org_sidebar_nav button[aria-expanded='true']",
      text: "#{organization.short_name} Registrations"

    # Reaching another section's row means opening that section first, the way a reader does
    within("#org_sidebar_nav") do
      click_button "#{organization.short_name} Registrations"
      click_link "Search Registrations"
    end

    expect(page).to have_current_path("/o/#{slug}/registrations", ignore_query: true)
    expect_open("#{organization.short_name} Registrations")
    expect(page).to have_css "#org_sidebar_nav a[aria-current='true']", text: "Search Registrations"
    expect(page).to have_no_css "#org_sidebar_nav a[aria-current]", text: "Search Impounded Vehicles"
  end

  # Both rows are organized/bikes#new, told apart only by the query string
  it "tells the two add-a-bike rows apart by their full path" do
    visit "/o/#{slug}/bikes/new"

    expect(page).to have_css "#org_sidebar_nav a[aria-current]", text: "Add a bike"
    expect(page).to have_no_css "#org_sidebar_nav a[aria-current]", text: "New unregistered notification"

    visit "/o/#{slug}/bikes/new?parking_notification=true"

    expect(page).to have_css "#org_sidebar_nav a[aria-current]", text: "New unregistered notification"
    expect(page).to have_no_css "#org_sidebar_nav a[aria-current]", text: "Add a bike"
  end

  # The sidebar stands in for the navbar on every page a member sees, including ones no
  # row points at — where the design's default of the first group open stands
  it "opens the first group on a page no row matches" do
    visit "/my_account"

    expect_open("#{organization.short_name} Registrations")
    expect(page).to have_no_css "#org_sidebar_nav a[aria-current]", visible: :all
  end
end
