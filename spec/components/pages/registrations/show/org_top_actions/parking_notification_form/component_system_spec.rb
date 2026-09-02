# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::OrgTopActions::ParkingNotificationForm::Component, :js, type: :system do
  let(:controller_id) { "registrations--show--parking-notification-form" }
  let(:map_selector) { "[data-#{controller_id}-target='map']" }
  # Defined in utils/maplibre.js since #3954, so there is no Ruby constant to reuse
  let(:maps_host) { "https://maps.bikeindex.org" }
  let(:preview_path) { "/rails/view_components/pages/registrations/show/org_top_actions/parking_notification_form/component/default" }
  # The preview opens the parking panel on load; an empty panel starts it closed
  let(:closed_preview_path) { "#{preview_path}?panel=" }
  let(:organization) { FactoryBot.create(:organization) }
  let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }

  # Coordinates the mocked device reports (SF Bay) and the address /reverse_geocode returns
  let(:latitude) { "37.8698" }
  let(:longitude) { "-122.2585" }
  # A resolved pin is mirrored into the URL — there is no on-page location readout
  let(:located_url) { /map_lat=37\.8698.*map_lng=-122\.2585.*map_zoom=15\.50/ }
  let(:country) { Country.united_states }
  let!(:state) { FactoryBot.create(:state_california) }
  # How long the stubbed endpoint takes to answer
  let(:geocode_delay) { 0 }
  let(:geocode_address) do
    {street: "2363a Bryant Street", city: "San Francisco", postal_code: "94110",
     region_record_id: state.id, region_string: nil, country_id: country.id}
  end
  # A pin anywhere else resolves to a different address, so the two can be told apart
  let(:moved_address) do
    geocode_address.merge(street: "1200 Valencia Street", city: "Oakland", postal_code: "94612")
  end

  def coordinate(field)
    find("input[name='parking_notification[#{field}]']", visible: false).value
  end

  # Read an AddressGroup field's value regardless of the country/region visibility
  def address_field(attribute)
    find("[name$='[#{attribute}]']", visible: :all).value
  end

  # The map paints to a canvas, so none of its state reaches the DOM. Reach the
  # MapLibre instance through the Stimulus registry and read it back via its API.
  # The pin's hidden fields are read in the same tick as the centre, so comparing the
  # two can't race the moveend that stamps them.
  # No JS comments in here — the driver collapses the script onto one line, so a
  # `//` would comment out everything after it.
  # accuracyRadius is stop 4 of the interpolation: the zoom-0 pixel radius, which
  # scales with the accuracy the browser reported.
  def map_snapshot
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("[data-controller~='#{controller_id}']")
        const map = el && window.Stimulus.getControllerForElementAndIdentifier(el, "#{controller_id}")?.map
        if (!map || !map.loaded() || !map.getLayer("device-dot")) { return null }
        const dot = map.queryRenderedFeatures({layers: ["device-dot"]})[0]
        const field = (name) => parseFloat(document.querySelector("input[name='parking_notification[" + name + "]']").value)
        return {
          center: map.getCenter().toArray(),
          zoom: map.getZoom(),
          pin: [field("longitude"), field("latitude")],
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

  # Put the mouse on the middle of the map, where both gestures below start
  def at_map_center(playwright_page)
    box = playwright_page.locator(map_selector).bounding_box
    center = [box["x"] + box["width"] / 2, box["y"] + box["height"] / 2]
    playwright_page.mouse.move(*center)
    center
  end

  # Pan the map the way a user does — press, move, release over the canvas
  def drag_map(x_offset, y_offset)
    page.driver.with_playwright_page do |playwright_page|
      center_x, center_y = at_map_center(playwright_page)
      playwright_page.mouse.down
      playwright_page.mouse.move(center_x + x_offset, center_y + y_offset, steps: 12)
      playwright_page.mouse.up
    end
  end

  # Whether the expanded map actually covers the page. The class that expands it is
  # not enough to assert: MapLibre sets position:relative on the same element, so
  # the class can apply while nothing moves.
  def map_geometry
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("#{map_selector}")
        const rect = el.getBoundingClientRect()
        const root = document.documentElement
        return {
          position: window.getComputedStyle(el).position,
          coversPage: Math.abs(rect.width - root.clientWidth) < 2 && Math.abs(rect.height - root.clientHeight) < 2,
          nativeFullscreen: Boolean(document.fullscreenElement)
        }
      })()
    JS
  end

  # Zoom the way a user does — a wheel/trackpad scroll over the centre of the map
  def scroll_map(delta)
    page.driver.with_playwright_page do |playwright_page|
      at_map_center(playwright_page)
      playwright_page.mouse.wheel(0, delta)
    end
  end

  # The mode toggle hides and re-shows the map, and MapLibre needs a frame to
  # re-measure before it tracks a drag — so retry until the pin actually moves
  def drag_map_until_moved
    start = coordinate("longitude")
    Timeout.timeout(20) do
      while coordinate("longitude") == start
        drag_map(160, 60)
        10.times {
          break if coordinate("longitude") != start
          sleep 0.05
        }
      end
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

  # The panel opened in impound mode: retitled by the panel controller, kind
  # preselected and the reason chooser hidden by the form controller
  def expect_impound_mode
    # The heading is CSS-uppercased, so match case-insensitively
    expect(page).to have_content(/Impound this #{bike.type}/i, wait: 10)
    expect(page).to have_no_content("Notification because")
    expect(find("input[name='parking_notification[kind]'][value='impound_notification']", visible: :all)).to be_checked
  end

  # The device fix has landed: the pin is on it and mirrored into the URL. MapLibre
  # names the locate button only once its async permission check resolves, and axe
  # fails a button that has no name yet — so wait for that before auditing.
  def expect_located_pin
    expect(page).to have_current_path(located_url, url: true, wait: 10)
    expect(coordinate("latitude")).to eq(latitude)
    expect(coordinate("longitude")).to eq(longitude)
    expect(page).to have_button("Create parking notification", disabled: false)
    expect(page).to have_button("Find my location")
    expect_axe_clean
  end

  # No visit here — the driver boots its page on demand, so the routes and
  # permissions install against a blank page and every example visits its own URL
  before do
    move_device_to(latitude: latitude.to_f, longitude: longitude.to_f, accuracy: 20)
    # capture for the cross-thread route handler
    address, moved, device_longitude, delay = geocode_address, moved_address, longitude, geocode_delay
    page.driver.with_playwright_page do |playwright_page|
      context = playwright_page.context
      context.grant_permissions(["geolocation"])
      # Stub our reverse-geocode endpoint so the address resolves without hitting Google
      context.route("**/reverse_geocode?**", proc { |route, request|
        sleep delay
        route.fulfill(status: 200, json: request.url.include?("longitude=#{device_longitude}") ? address : moved)
      })
      # Serve an empty MapLibre style so the map builds without fetching basemap tiles
      context.route("#{maps_host}/**", proc { |route, _request|
        route.fulfill(status: 200, json: {version: 8, sources: {}, layers: []})
      })
    end
  end

  it "geolocates, splits the address into fields, toggles modes, and keeps drafts across a reload" do
    visit closed_preview_path

    # Submit is disabled until a location is chosen
    expect(page).to have_button("Create parking notification", disabled: true, visible: :all)

    # Opening the panel geolocates; the pin + zoom mirrored into the URL are the
    # only trace of it, so a reload restores them
    click_button "Parking notification"

    expect_located_pin
    # The MapLibre map renders under the centre pin, with its zoom + expand controls
    expect(page).to have_css(".maplibregl-canvas")
    expect(page).to have_css(".maplibregl-ctrl-zoom-in", visible: :all)
    expect(page).to have_css(".maplibregl-ctrl-fullscreen", visible: :all)

    # Manual entry reveals the fields and geocodes the pin into them
    find("label", text: "Enter address manually").click

    expect(page).to have_field("Address or intersection", with: "2363a Bryant Street")
    expect(page).to have_field("City", with: "San Francisco")
    expect(page).to have_field("Postal code", with: "94110")
    # The endpoint hands back ids, so the selects are set directly rather than matched by label
    expect(address_field("region_record_id")).to eq(state.id.to_s)
    expect(address_field("country_id")).to eq(country.id.to_s)
    expect(coordinate("use_entered_address")).to eq("true")
    expect_axe_clean

    # A hand-edited address survives toggling modes (the seed only fills when blank)
    fill_in "Address or intersection", with: "NE corner of 24th & Bryant"

    find("label", text: "Set on map").click

    expect(page).to have_no_field("Address or intersection")
    expect(coordinate("use_entered_address")).to eq("false")

    find("label", text: "Enter address manually").click

    expect(page).to have_field("Address or intersection", with: "NE corner of 24th & Bryant")

    # Moving the pin makes that address the wrong one, so the fresh geocode replaces
    # it — the hand-edit only survives while it still describes where the pin sits
    find("label", text: "Set on map").click
    drag_map_until_moved

    find("label", text: "Enter address manually").click

    expect(page).to have_field("Address or intersection", with: "1200 Valencia Street")
    expect(page).to have_field("City", with: "Oakland")
    expect(page).to have_field("Postal code", with: "94612")

    # The message + internal notes drafts survive a reload via form-persist
    find("textarea[name='parking_notification[internal_notes]']").set("Third report this week")
    fill_in "Optional message to send to the owner", with: "Blocking the bike lane"

    visit "#{preview_path}?panel=parking"

    expect(page).to have_field("Optional message to send to the owner", with: "Blocking the bike lane")
    expect(address_field("internal_notes")).to eq("Third report this week")
  end

  # The response can land after they've started typing
  context "when the geocode is slow to answer" do
    let(:geocode_delay) { 2 }

    it "fills the blanks but leaves the field they typed into while it was in flight" do
      visit "#{preview_path}?panel=parking"

      expect(page).to have_current_path(located_url, url: true, wait: 10)

      find("label", text: "Enter address manually").click
      fill_in "Address or intersection", with: "NE corner of 24th & Bryant"

      expect(page).to have_field("City", with: "San Francisco", wait: 10)
      expect(page).to have_field("Address or intersection", with: "NE corner of 24th & Bryant")
    end
  end

  # The ?panel=parking load path auto-opens the panel on connect, so geolocation
  # must fire despite the accordion/panel controller connect order. Everything
  # below the canvas can regress silently too — the pin, the device marker and the
  # submitted coordinates leave no DOM behind.
  it "geolocates on load, tracks the pin through zoom, drag and the locate button, expands, and prefers a URL pin" do
    visit "#{preview_path}?panel=parking"

    expect_located_pin

    # The device marker sits on the reported fix, haloed by its accuracy
    placed = map_settling_on { |snapshot| snapshot["layers"].sort == %w[device-accuracy device-dot] }
    expect(rounded(placed["device"])).to eq([longitude.to_f, latitude.to_f])
    expect(rounded(placed["center"])).to eq([longitude.to_f, latitude.to_f])
    loose_accuracy_radius = placed["accuracyRadius"]

    # Scrolling over the map zooms it, leaving the pin where it is
    scroll_map(-240)

    zoomed = map_settling_on { |snapshot| snapshot["zoom"] > placed["zoom"] }
    expect(rounded(zoomed["pin"])).to eq(rounded(placed["pin"]))

    # Dragging moves the pin: the coordinates follow the map centre
    drag_map(160, 60)

    # Wait for moveend to stamp the new centre, then check the form tracks it
    dragged = map_settling_on { |snapshot| (snapshot["pin"][1] - latitude.to_f).abs > 1e-5 }
    expect(rounded(dragged["pin"], 5)).to eq(rounded(dragged["center"], 5))
    # The device marker is not the pin, so it stays where the device is
    expect(rounded(dragged["device"])).to eq([longitude.to_f, latitude.to_f])
    # Panning never resolves an address — the pin itself is the location
    expect(address_field("street")).to eq("")

    # The locate button returns to the device, adopting a newer and tighter fix
    move_device_to(latitude: 37.7749, longitude: -122.4194, accuracy: 5)
    find(".maplibregl-ctrl-geolocate").click

    # Wait for the flight to land and stamp the form. The control fitBounds() to
    # the accuracy circle rather than centring exactly, so allow ~500m against
    # what is a ~15km jump from Berkeley
    relocated = map_settling_on { |snapshot| (snapshot["pin"][0] + 122.4194).abs < 0.005 }
    expect(relocated["pin"][1]).to be_within(0.005).of(37.7749)
    expect(relocated["center"][0]).to be_within(0.005).of(-122.4194)
    # The marker moved with it, onto the exact fix the control reported
    expect(rounded(relocated["device"], 3)).to eq([-122.419, 37.775])
    # The halo tracks the reported accuracy: 20m -> 5m shrinks it
    expect(relocated["accuracyRadius"]).to be < loose_accuracy_radius

    # At this viewport expanding covers the page rather than calling for browser
    # fullscreen, so the site chrome stays reachable (phones get fullscreen)
    click_button "Expand map"

    expect(page).to have_button("Exit expanded map")
    expect(map_geometry).to eq("position" => "fixed", "coversPage" => true, "nativeFullscreen" => false)

    click_button "Exit expanded map"

    expect(page).to have_button("Expand map")
    expect(map_geometry).to include("position" => "relative", "coversPage" => false)

    # A shared link / reload carries the pin coordinates; they win over the
    # (slower, less intentional) device geolocation
    visit "#{preview_path}?panel=parking&map_lat=40.5&map_lng=-74.25&map_zoom=12"

    expect(page).to have_current_path(/map_lat=40\.500000/, url: true, wait: 10)
    expect(coordinate("latitude")).to eq("40.5")
    expect(coordinate("longitude")).to eq("-74.25")
  end

  # WebGL/MapLibre can be unavailable (disabled GPU, blocked CDN); the coordinates
  # are already stamped, so the form has to stay submittable without a map
  context "when MapLibre can't be loaded" do
    before do
      page.driver.with_playwright_page do |playwright_page|
        playwright_page.context.route("https://cdn.jsdelivr.net/npm/maplibre-gl@**", proc { |route, _request| route.abort })
      end
    end

    it "replaces the map and its hint with a message, keeping the located coordinates" do
      visit "#{preview_path}?panel=parking"

      expect(page).to have_content("The map couldn't be loaded", wait: 10)
      # The hint belongs to the map, so it goes with it
      expect(page).to have_no_content("Drag the map so the pin marks the spot")
      # The map only builds once a fix lands, so the coordinates are already stamped
      expect(coordinate("latitude")).to eq(latitude)
      expect(page).to have_button("Create parking notification", disabled: false)
      expect_axe_clean
    end
  end

  # The org fallback is somewhere to point the map, not a spot anyone picked — it
  # must not leak into the URL or seed the manual-entry fields with the org's address
  context "when the browser refuses to geolocate" do
    before { page.driver.with_playwright_page { |playwright_page| playwright_page.context.clear_permissions } }

    it "falls back to the org location, and only geocodes once the pin has been moved" do
      visit "#{preview_path}?panel=parking"

      # The map is only built once the request has failed over to the org location
      expect(page).to have_css(".maplibregl-canvas", wait: 10)
      expect(coordinate("latitude")).to eq(organization.map_focus_coordinates[:latitude].to_s)
      expect(page.current_url).to_not include("map_lat")

      find("label", text: "Enter address manually").click

      expect(page).to have_field("Address or intersection", with: "")
      expect(address_field("city")).to eq("")

      # Moving the map makes the pin a chosen spot, so manual entry seeds from it
      find("label", text: "Set on map").click
      drag_map_until_moved

      find("label", text: "Enter address manually").click

      expect(page).to have_field("Address or intersection", with: "1200 Valencia Street")
      expect(page).to have_field("City", with: "Oakland")
    end
  end

  # Opening via the Impound trigger preselects the impound kind
  it "titles for the bike type, preselects impound, hides the reason chooser, and survives a reload" do
    visit closed_preview_path
    click_button "Impound"

    expect_impound_mode

    # The impound trigger's panel name reopens the shared form in impound mode
    visit "#{preview_path}?panel=impound"

    expect_impound_mode
  end

  # A bike with an earlier notification can mark the new one as a repeat
  context "when the bike has an earlier notification" do
    let!(:earlier_notification) { FactoryBot.create(:parking_notification, bike:, organization:) }

    it "offers repeat first and collapses the location controls while it's selected" do
      visit closed_preview_path
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
end
