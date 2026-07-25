# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::OrgTopActionsParkingNotificationForm::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/registrations/show/org_top_actions_parking_notification_form/component/default" }
  let(:organization) { FactoryBot.create(:organization) }
  let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }

  # Coordinates the mocked device reports (SF Bay) and the address Mapbox returns
  let(:latitude) { "37.8698" }
  let(:longitude) { "-122.2585" }
  let(:place_name) { "2363a Bryant Street, San Francisco, California 94110, United States" }
  # The readout is the pin's coordinates, never a reverse-geocoded address
  let(:located_status) { "Using your current location · 37.86980, -122.25850" }
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

  # The map paints to a canvas, so none of its state reaches the DOM. The controller
  # hangs the MapLibre instance off the container; read it back through the public API.
  # No JS comments in here — the driver collapses the script onto one line, so a
  # `//` would comment out everything after it.
  # accuracyRadius is stop 4 of the interpolation: the zoom-0 pixel radius, which
  # scales with the accuracy the browser reported.
  def map_snapshot
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("[data-registrations--show--parking-notification-target='map']")
        const map = el && el.map
        if (!map || !map.loaded() || !map.getLayer("device-dot")) { return null }
        const dot = map.queryRenderedFeatures({layers: ["device-dot"]})[0]
        return {
          center: map.getCenter().toArray(),
          layers: ["device-accuracy", "device-dot"].filter((id) => Boolean(map.getLayer(id))),
          device: dot ? dot.geometry.coordinates : null,
          accuracyRadius: map.getPaintProperty("device-accuracy", "circle-radius")[4]
        }
      })()
    JS
  end

  # MapLibre keeps painting after the DOM has settled, so poll for the condition.
  # A not-ready snapshot arrives as {} (the driver maps a JS null to an empty hash,
  # which is truthy), so test it with present? rather than for nil.
  def map_settling_on
    snapshot = nil
    Timeout.timeout(15) do
      loop do
        snapshot = map_snapshot
        break if snapshot.present? && yield(snapshot)
        sleep 0.25
      end
    end
    snapshot
  rescue Timeout::Error
    raise "map never settled; last snapshot: #{snapshot.inspect}"
  end

  # Pan the map the way a user does — press, move, release over the canvas
  def drag_map(x_offset, y_offset)
    page.driver.with_playwright_page do |playwright_page|
      box = playwright_page.locator("[data-registrations--show--parking-notification-target='map']").bounding_box
      center_x = box["x"] + box["width"] / 2
      center_y = box["y"] + box["height"] / 2
      playwright_page.mouse.move(center_x, center_y)
      playwright_page.mouse.down
      playwright_page.mouse.move(center_x + x_offset, center_y + y_offset, steps: 12)
      playwright_page.mouse.up
    end
  end

  def move_device_to(latitude:, longitude:, accuracy:)
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.set_geolocation({latitude:, longitude:, accuracy:})
    end
  end

  def rounded(coordinates, digits = 4)
    coordinates.map { |coordinate| coordinate.round(digits) }
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
      context.route("https://api.mapbox.com/geocoding/**", proc { |route, _request|
        route.fulfill(status: 200, json: {features: [feature]})
      })
      # Serve an empty MapLibre style so the map builds without fetching basemap tiles
      context.route("#{MAPS_HOST}/**", proc { |route, _request|
        route.fulfill(status: 200, json: {version: 8, sources: {}, layers: []})
      })
    end
  end

  it "geolocates, splits the address into fields, and toggles between modes" do
    # Submit is disabled until a location is chosen
    expect(page).to have_button("Create parking notification", disabled: true, visible: :all)

    # Opening the panel geolocates and reads the coordinates back
    click_button "Parking notification"

    expect(page).to have_content(located_status, wait: 10)
    # The green status dot appears alongside the location readout
    expect(page).to have_css("[data-registrations--show--parking-notification-target='statusDot']", visible: true)
    # Map mode never surfaces a geocoded address — the pin is the location
    expect(page).to have_no_content("Bryant Street")
    expect(coordinate("latitude")).to eq(latitude)
    expect(coordinate("longitude")).to eq(longitude)
    expect(page).to have_button("Create parking notification", disabled: false)
    # The MapLibre map renders under the centre pin, with its zoom controls
    expect(page).to have_css(".maplibregl-canvas")
    expect(page).to have_css(".maplibregl-ctrl-zoom-in", visible: :all)
    # The pin + zoom are mirrored into the URL so a reload restores them
    expect(page.current_url).to include("map_lat=37.8698").and include("map_lng=-122.2585").and include("map_zoom=")
    expect_axe_clean

    # Manual entry hides the readout and geocodes the pin into the fields
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

    find("label", text: "Set on map").click

    expect(page).to have_content(located_status)
    expect(page).to have_no_field("Address or intersection")
    expect(coordinate("use_entered_address")).to eq("false")

    find("label", text: "Enter address manually").click

    expect(page).to have_field("Address or intersection", with: "NE corner of 24th & Bryant")
  end

  # The ?panel=parking load path auto-opens the panel on connect; geolocation
  # must still fire despite the accordion/panel controller connect order
  context "when loaded with the panel already open" do
    it "geolocates on load, without a click, and prefers a pin carried in the URL" do
      visit "#{preview_path}?panel=parking"

      expect(page).to have_content(located_status, wait: 10)
      expect(coordinate("latitude")).to eq(latitude)
      expect(coordinate("longitude")).to eq(longitude)
      expect(page).to have_button("Create parking notification", disabled: false)
      expect_axe_clean

      # A shared link / reload carries the pin coordinates; they win over the
      # (slower, less intentional) device geolocation
      visit "#{preview_path}?panel=parking&map_lat=40.5&map_lng=-74.25&map_zoom=12"

      expect(page).to have_button("Create parking notification", disabled: false, wait: 10)
      expect(coordinate("latitude")).to eq("40.5")
      expect(coordinate("longitude")).to eq("-74.25")
    end
  end

  # Everything below the canvas can regress silently — the pin, the device marker
  # and the submitted coordinates leave no DOM behind
  context "the map itself" do
    it "moves the pin with the map, keeps the device marker on the latest fix, and never geocodes" do
      visit "#{preview_path}?panel=parking"
      expect(page).to have_content(located_status, wait: 10)

      # The device marker sits on the reported fix, haloed by its accuracy
      placed = map_settling_on { |snapshot| snapshot["layers"].sort == %w[device-accuracy device-dot] }
      expect(rounded(placed["device"])).to eq([longitude.to_f, latitude.to_f])
      expect(rounded(placed["center"])).to eq([longitude.to_f, latitude.to_f])
      loose_accuracy_radius = placed["accuracyRadius"]

      # Dragging moves the pin: the coordinates follow the map centre
      drag_map(160, 60)

      # Wait for moveend to stamp the new centre, then check the form tracks it
      dragged = map_settling_on { (coordinate("latitude").to_f - latitude.to_f).abs > 1e-5 }
      expect(coordinate("latitude").to_f.round(5)).to eq(dragged["center"][1].round(5))
      expect(coordinate("longitude").to_f.round(5)).to eq(dragged["center"][0].round(5))
      # The device marker is not the pin, so it stays where the device is
      expect(rounded(dragged["device"])).to eq([longitude.to_f, latitude.to_f])
      # Panning never resolves an address — the readout is coordinates throughout
      expect(page).to have_no_content("Bryant Street")
      expect(find("[data-registrations--show--parking-notification-target='statusText']").text)
        .to match(/\A-?\d+\.\d+, -?\d+\.\d+\z/)

      # The locate button returns to the device, adopting a newer and tighter fix
      move_device_to(latitude: 37.7749, longitude: -122.4194, accuracy: 5)
      find(".maplibregl-ctrl-geolocate").click

      # Wait for the flight to land and stamp the form. The control fitBounds() to
      # the accuracy circle rather than centring exactly, so allow ~500m against
      # what is a ~15km jump from Berkeley
      relocated = map_settling_on { (coordinate("longitude").to_f + 122.4194).abs < 0.005 }
      expect(coordinate("latitude").to_f).to be_within(0.005).of(37.7749)
      expect(relocated["center"][0]).to be_within(0.005).of(-122.4194)
      # The marker moved with it, onto the exact fix the control reported
      expect(rounded(relocated["device"], 3)).to eq([-122.419, 37.775])
      # The halo tracks the reported accuracy: 20m -> 5m shrinks it
      expect(relocated["accuracyRadius"]).to be < loose_accuracy_radius
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
      expect(page).to have_no_content("Set on map")

      # Choosing "First notice" reveals the location controls
      find("label", text: "First notice").click
      expect(page).to have_content("Set on map")
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
