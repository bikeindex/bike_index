# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::OrgTopActions::ParkingNotificationForm::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/registrations/show/org_top_actions/parking_notification_form/component/default" }
  let(:organization) { FactoryBot.create(:organization) }
  let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }

  # Coordinates the mocked device reports (SF Bay) and the address Mapbox returns
  let(:latitude) { "37.8698" }
  let(:longitude) { "-122.2585" }
  let(:place_name) { "2363a Bryant Street, San Francisco, California 94110, United States" }
  # The status drops the trailing ", United States"
  let(:located_status) { "Using your current location · 2363a Bryant Street, San Francisco, California 94110" }
  let(:geocode_feature) do
    {
      place_name:,
      address: "2363a",
      text: "Bryant Street",
      context: [
        {id: "postcode.1", text: "94110"},
        {id: "place.1", text: "San Francisco"},
        {id: "region.1", text: "California"},
        {id: "country.1", text: "United States"}
      ]
    }
  end

  def coordinate(field)
    find("input[name='parking_notification[#{field}]']", visible: false).value
  end

  # Read an AddressGroup field's value regardless of the country/region visibility
  def address_field(attribute)
    find("[name$='[#{attribute}]']", visible: :all).value
  end

  before do
    stub_const("ENV", ENV.to_hash.merge("MAPBOX_MAPPING" => "pk.test-token"))
    visit preview_path
    feature = geocode_feature # capture for the cross-thread route handler
    page.driver.with_playwright_page do |playwright_page|
      context = playwright_page.context
      context.grant_permissions(["geolocation"])
      context.set_geolocation({latitude: latitude.to_f, longitude: longitude.to_f, accuracy: 20})
      # Stub Mapbox reverse-geocode so the address resolves without the network
      context.route("https://api.mapbox.com/**", proc { |route, _request|
        route.fulfill(status: 200, json: {features: [feature]})
      })
    end
  end

  it "geolocates, splits the address into fields, and toggles between modes" do
    # Submit is disabled until a location is chosen
    expect(page).to have_button("Create parking notification", disabled: true, visible: :all)

    # Opening the panel geolocates and reverse-geocodes into the status
    click_button "Parking notification"

    expect(page).to have_content(located_status, wait: 10)
    # The green status dot appears alongside the location readout
    expect(page).to have_css("[data-registrations--show--parking-notification-target='statusDot']", visible: true)
    expect(coordinate("latitude")).to eq(latitude)
    expect(coordinate("longitude")).to eq(longitude)
    expect(page).to have_button("Create parking notification", disabled: false)
    expect_axe_clean

    # Manual entry hides the readout and splits the location across the fields
    find("label", text: "Enter address manually").click

    expect(page).to have_field("Address or intersection", with: "2363a Bryant Street")
    expect(page).to have_field("City", with: "San Francisco")
    expect(page).to have_field("Postal code", with: "94110")
    expect(address_field("region_string")).to eq("California")
    expect(page).to have_no_content("Using your current location")
    expect(coordinate("use_entered_address")).to eq("true")
    expect_axe_clean

    # A hand-edited address survives toggling modes (the seed only fills when blank)
    fill_in "Address or intersection", with: "NE corner of 24th & Bryant"

    find("label", text: "Use my current location").click

    expect(page).to have_content(located_status)
    expect(page).to have_no_field("Address or intersection")
    expect(coordinate("use_entered_address")).to eq("false")

    find("label", text: "Enter address manually").click

    expect(page).to have_field("Address or intersection", with: "NE corner of 24th & Bryant")
  end

  # The ?panel=parking load path auto-opens the panel on connect; geolocation
  # must still fire despite the accordion/panel controller connect order
  context "when loaded with the panel already open" do
    it "geolocates on load, without a click" do
      visit "#{preview_path}?panel=parking"

      expect(page).to have_content(located_status, wait: 10)
      expect(coordinate("latitude")).to eq(latitude)
      expect(coordinate("longitude")).to eq(longitude)
      expect(page).to have_button("Create parking notification", disabled: false)
      expect_axe_clean
    end
  end

  # Opening via the Impound trigger preselects the impound kind
  context "opened in impound mode" do
    it "titles for the bike type, preselects impound, and hides the reason chooser" do
      click_button "Impound"

      # The heading is CSS-uppercased, so match case-insensitively
      expect(page).to have_content(/Impound this #{bike.type}/i, wait: 10)
      expect(page).to have_no_content("Notification because")
      expect(find("input[name='parking_notification[kind]'][value='impound_notification']", visible: :all)).to be_checked
    end

    it "restores impound mode after a reload" do
      click_button "Impound"
      expect(page).to have_content(/Impound this #{bike.type}/i, wait: 10)

      # The impound trigger's panel name reopens the shared form in impound mode
      visit "#{preview_path}?panel=impound"

      expect(page).to have_content(/Impound this #{bike.type}/i, wait: 10)
      expect(page).to have_no_content("Notification because")
      expect(find("input[name='parking_notification[kind]'][value='impound_notification']", visible: :all)).to be_checked
    end
  end

  # A bike with an earlier notification can mark the new one as a repeat
  context "when the bike has an earlier notification" do
    let!(:earlier_notification) { FactoryBot.create(:parking_notification, bike:, organization:) }

    it "offers repeat first and collapses the location controls while it's selected" do
      # Re-render now that the earlier notification exists (it's created after the outer visit)
      visit preview_path
      click_button "Parking notification"

      # Repeat is offered first, before "First notice"
      labels = all("label").map(&:text)
      expect(labels.index { |t| t.start_with?("Repeat #") }).to be < labels.index("First notice")

      # A recent earlier notification preselects repeat, so the location controls start collapsed
      expect(page).to have_no_content("Use my current location")

      # Choosing "First notice" reveals the location controls
      find("label", text: "First notice").click
      expect(page).to have_content("Use my current location")
    end
  end

  # The message + internal notes drafts survive a reload via form-persist
  context "draft persistence" do
    it "restores the message and internal notes after a reload" do
      click_button "Parking notification"

      find("textarea[name='parking_notification[internal_notes]']").set("Third report this week")
      fill_in "Optional message to send to the owner", with: "Blocking the bike lane"

      # Reload with the panel open; form-persist rehydrates the two marked fields
      visit "#{preview_path}?panel=parking"

      expect(page).to have_field("Optional message to send to the owner", with: "Blocking the bike lane")
      expect(address_field("internal_notes")).to eq("Third report this week")
    end
  end
end
