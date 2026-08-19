# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized parking notifications", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[parking_notifications impound_bikes]) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:base_url) { "/o/#{organization.to_param}/parking_notifications" }
  let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }

  let!(:unregistered) { FactoryBot.create(:parking_notification_unregistered, organization:, user:) }
  let!(:abandoned) { FactoryBot.create(:parking_notification_organized, organization:, user:, kind: "appears_abandoned_notification") }
  let!(:retrieved) { FactoryBot.create(:parking_notification_organized, :retrieved, organization:, user:) }

  before do
    # The bike show page renders in a readonly (reading-role) connection, so
    # pre-create the static gear records it builds lazily — otherwise the first
    # render attempts a write and raises ActiveRecord::ReadOnlyError.
    RearGearType.fixed
    FrontGearType.fixed
    # Below the sidebar's 760px breakpoint, where it's an overlay behind the top
    # bar's hamburgler. Chrome's --window-size flag is unreliable in headless
    # mode, so resize explicitly.
    page.current_window.resize_to(720, 2000)
    visit new_session_path
    fill_in "Email", with: user.email
    click_button "Continue"
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
  end

  def click_filter(text)
    link = find("a.linkWithSortableSearchParams", text: text, visible: :all)
    # Bootstrap dropdowns hide menu items until the parent toggle is clicked.
    link.find(:xpath, "ancestor::li[contains(@class,'nav-item')][1]").find("a.dropdown-toggle").click
    link.click
  end

  def row_for(notification) = "tr[data-recordid='#{notification.id}']"

  it "creates a parking notification through the redesigned registration show page" do
    # The redesign is desktop-first; the mobile resize above is only for the
    # sidebar-as-overlay path the other example needs.
    page.current_window.resize_to(1400, 2000)
    visit registration_path(bike)

    # Open the parking-notification card in the org-admin action panel. The org
    # also has impound enabled, so scope to the notification trigger by its label.
    within("main") { click_button "Parking Notification" }

    # Skip the geolocation prompt by entering the address by hand; this reveals the
    # address fields and enables the (initially disabled) submit button.
    choose "Enter address manually", allow_label_click: true
    fill_in "parking_notification_street", with: "100 Main St"
    fill_in "parking_notification_city", with: "New York"
    choose "Parked incorrectly", allow_label_click: true

    expect {
      click_button "Create parking notification"
      expect(page).to have_content("Parking Notification for #{bike.type} created", wait: 10)
    }.to change(bike.parking_notifications, :count).by(1)

    notification = bike.reload.parking_notifications.last
    expect(notification.kind).to eq "parked_incorrectly_notification"
    expect(notification.organization).to eq organization
    expect(notification.user).to eq user
  end

  # A pin in the middle of a park has no address of its own, so the reverse geocode
  # answers with somewhere else entirely (the suite-wide New York stub). The pin is
  # the location; the geocoded address only describes it, and must not move it.
  context "with the pin somewhere that has no address" do
    # Middle of Golden Gate Park
    let(:latitude) { 37.759681 }
    let(:longitude) { -122.4275348 }

    def coordinate(field)
      find("input[name='parking_notification[#{field}]']", visible: false).value.to_f
    end

    it "creates the notification at the pin, not at the geocoded address" do
      page.current_window.resize_to(1400, 2000)
      page.driver.with_playwright_page do |playwright_page|
        browser_context = playwright_page.context
        browser_context.grant_permissions(["geolocation"])
        browser_context.set_geolocation({latitude:, longitude:, accuracy: 20})
        # Serve an empty MapLibre style so the map builds without fetching basemap tiles
        browser_context.route("https://maps.bikeindex.org/**", proc { |route, _request|
          route.fulfill(status: 200, json: {version: 8, sources: {}, layers: []})
        })
      end
      visit registration_path(bike)

      # Opening the panel geolocates, which stamps the hidden coordinate fields and
      # enables the (initially disabled) submit button
      within("main") { click_button "Parking Notification" }
      choose "Parked incorrectly", allow_label_click: true

      expect(page).to have_button("Create parking notification", disabled: false, wait: 15)
      expect(coordinate("latitude")).to be_within(0.000001).of(latitude)
      expect(coordinate("longitude")).to be_within(0.000001).of(longitude)

      expect {
        click_button "Create parking notification"
        expect(page).to have_content("Parking Notification for #{bike.type} created", wait: 10)
      }.to change(bike.parking_notifications, :count).by(1)

      notification = bike.reload.parking_notifications.last
      expect(notification.latitude).to be_within(0.000001).of(latitude)
      expect(notification.longitude).to be_within(0.000001).of(longitude)
      # The geocode ran and described a different place — its address is kept, its
      # coordinates are discarded
      expect(notification.street).to eq "278 Broadway"
      expect(notification.city).to eq "New York"
    end
  end

  it "creates a parking notification on the bike show page, then filters them through the dropdown menus" do
    # Create a parking notification through the bike show interface. Regression:
    # the "New parking notification" button must open the form (it was wired to
    # Bootstrap's collapse plugin, which is no longer loaded).
    visit bike_path(bike)
    expect(page).to have_css(".organized-access-panel")
    click_on "New parking notification"
    choose "Parked incorrectly"

    # The form requests the device location, which fills the hidden coordinate
    # fields and enables the (initially disabled) submit button. If the location
    # is unavailable it falls back to manual address entry — fill it in so the
    # notification is valid either way.
    expect(page).to have_button("Create parking notification!", disabled: false, wait: 15)
    if page.has_field?("parking_notification_street", visible: true, wait: 0)
      fill_in "parking_notification_street", with: "100 Main St"
      fill_in "parking_notification_city", with: "New York"
    end
    click_on "Create parking notification!"
    expect(page).to have_content("Parking Notification for #{bike.type} created", wait: 10)

    registered = bike.reload.parking_notifications.first
    expect(registered.kind).to eq "parked_incorrectly_notification"

    dismiss_flash_messages

    find("#org_sidebar_hamburgler").click
    within("#org_sidebar_nav") do
      click_button "Parking Notifications"
      click_link "Search Parking Notifications"
    end
    expect(page).to have_current_path(/\A#{Regexp.escape(base_url)}(\?|\z)/, wait: 10)

    # Default view (status=current) loads three current notifications via JSON.
    expect(page).to have_css(row_for(registered), wait: 20)
    expect(page).to have_css(row_for(unregistered))
    expect(page).to have_css(row_for(abandoned))
    expect(page).to have_css("tr.record-row", count: 3)

    # Regression: the click handler reads data-urlparams (not href), so this used to apply
    # only_unregistered due to a copy-paste in the template.
    click_filter("Registered bikes only")
    expect(page).to have_css(row_for(registered), wait: 20)
    expect(page).to have_css(row_for(abandoned))
    expect(page).not_to have_css(row_for(unregistered))
    expect(page).to have_css("tr.record-row", count: 2)

    # Clicking the active item toggles it off — unregistered comes back.
    click_filter("Registered bikes only")
    expect(page).to have_css(row_for(unregistered), wait: 20)
    expect(page).to have_css("tr.record-row", count: 3)

    # "Only unregistered bikes" hides the registered ones.
    click_filter("Only unregistered bikes")
    expect(page).to have_css(row_for(unregistered), wait: 20)
    expect(page).not_to have_css(row_for(registered))
    expect(page).not_to have_css(row_for(abandoned))
    expect(page).to have_css("tr.record-row", count: 1)

    # "All bikes" shows everything again.
    click_filter("All bikes")
    expect(page).to have_css("tr.record-row", count: 3, wait: 20)

    # Status dropdown: "Resolved" shows the retrieved notification.
    click_filter("Resolved notifications")
    expect(page).to have_css(row_for(retrieved), wait: 20)
    expect(page).not_to have_css(row_for(registered))
    expect(page).to have_css("tr.record-row", count: 1)

    # Toggle the active status off — back to the three current notifications.
    click_filter("Resolved notifications")
    expect(page).to have_css(row_for(registered), wait: 20)
    expect(page).to have_css("tr.record-row", count: 3)
    expect(page).not_to have_css(row_for(retrieved))

    # Kind dropdown narrows to a single kind.
    click_filter("Appears abandoned notifications")
    expect(page).to have_css(row_for(abandoned), wait: 20)
    expect(page).not_to have_css(row_for(registered))
    expect(page).to have_css("tr.record-row", count: 1)
  end
end
