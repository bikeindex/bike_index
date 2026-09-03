import { Controller } from '@hotwired/stimulus'
import { collapse, COLLAPSE_DURATION_MS } from 'utils/collapse_utils'
import { ExpandControl, groundRadiusStops, loadMapLibre, MAPS_STYLE_URL, OSM_ATTRIBUTION } from 'utils/maplibre'

/* global navigator */

// Connects to data-controller='registrations--show--parking-notification-form'
// The whole org-admin parking-notification panel: the accordion says which trigger
// opened it, which retitles the heading and preselects the impound kind. "Set on
// map" mode shows a map under a fixed centre pin: it seeds from the browser
// location (falling back to the organization's location), stamps the coordinates
// onto the form, and keeps the pin + zoom in the URL so a reload restores them.
// Moving the map moves the pin. "Enter address manually" reveals the
// UI::Forms::AddressGroup fields instead. Tiles come from our self-hosted MapLibre
// basemap.
const DEFAULT_ZOOM = 15.5

// The device's own position, so a dragged pin can be judged against where the
// phone thinks it is. The halo covers the accuracy the browser reported.
const DEVICE_ACCURACY_PAINT = {
  'circle-color': '#2563eb',
  'circle-opacity': 0.15
}

const DEVICE_DOT_PAINT = {
  'circle-radius': 5,
  'circle-color': '#2563eb',
  'circle-stroke-width': 2,
  'circle-stroke-color': 'white'
}

export default class extends Controller {
  static targets = ['latitude', 'longitude', 'accuracy', 'submit', 'addressGroup',
    'useEnteredAddress', 'heading', 'locationMode', 'kindGroup', 'locationSection',
    'mapSection', 'mapFrame', 'map', 'mapUnavailable']

  static values = {
    notificationHeading: String,
    impoundHeading: String,
    defaultKind: String,
    orgLatitude: Number,
    orgLongitude: Number
  }

  // The accordion opens a panel as soon as its own module lands, so `shown` can be
  // spent before this lazily loaded one arrives — it records the name it opened as
  connect () {
    if (this.element.dataset.openedAs) this.applyMode(this.element.dataset.openedAs)
  }

  panelShown (event) {
    this.applyMode(event.detail?.name)
  }

  applyMode (name) {
    const impound = name === 'impound'
    if (this.hasHeadingTarget) {
      this.headingTarget.textContent = impound ? this.impoundHeadingValue : this.notificationHeadingValue
    }
    const radio = this.element.querySelector(`input[name$="[kind]"][value="${impound ? 'impound_notification' : this.defaultKindValue}"]`)
    if (radio) radio.checked = true
    // Impound preselects the kind, so hide the "Notification because" chooser
    if (this.hasKindGroupTarget) this.toggle(this.kindGroupTarget, !impound)
    // A recent earlier notification preselects "repeat", so sync on open (no animation)
    this.applyRepeat(this.repeatSelected, 0)
  }

  // Not collapse()'s default by another name: applyRepeat forwards this to startLocation,
  // which defaults to 0 and would resize the map before the reveal finished
  selectRepeat (event) {
    this.applyRepeat(event.target.value === 'true', COLLAPSE_DURATION_MS)
  }

  get repeatSelected () {
    return this.element.querySelector("input[name$='[is_repeat]'][value='true']")?.checked || false
  }

  // A repeat reuses the earlier notification's location, so collapse the location
  // controls; a hidden required field would otherwise block submit. Deferring the
  // map until the controls are actually revealed keeps a repeat from loading tiles
  // (and burning a geocode) for a map nobody sees
  applyRepeat (repeat, duration) {
    if (this.hasLocationSectionTarget) collapse(repeat ? 'hide' : 'show', this.locationSectionTarget, duration)
    if (repeat) {
      this.setManualRequired(false)
      this.enableSubmit()
    } else if (!this.manualMode) {
      this.startLocation(duration)
    }
  }

  // Segmented control: "current" places a pin on the map, "entered" reveals the
  // address fields
  selectLocationMode (event) {
    if (event.target.value === 'entered') this.enterManually()
    else this.startLocation()
  }

  // Reflect the chosen mode across the radios, the hidden flag, the required
  // fields and which of the map / address panels is showing
  applyLocationMode (manual) {
    const value = manual ? 'entered' : 'current'
    this.locationModeTargets.forEach((radio) => { radio.checked = radio.value === value })
    if (this.hasUseEnteredAddressTarget) this.useEnteredAddressTarget.value = manual
    this.setManualRequired(manual)
    this.toggle(this.addressGroupTarget, manual)
    this.toggle(this.mapSectionTarget, !manual)
  }

  // Show the map and seed the pin. Once a location has resolved this session the
  // pin is already placed, so just re-reveal the map.
  startLocation (revealDuration = 0) {
    this.applyLocationMode(false)

    if (this.located) {
      // The frame may still be mid-collapse, so measure once it has settled
      window.setTimeout(() => this.map?.resize(), revealDuration)
      return
    }

    const stored = this.storedMapState
    if (stored) {
      this.locate(stored.latitude, stored.longitude, { zoom: stored.zoom })
    } else {
      // The org location makes the form submittable at once; the map itself waits
      // for the device fix so it doesn't load tiles it's about to pan away from
      this.setCoordinates(this.orgLatitudeValue, this.orgLongitudeValue)
      this.requestLocation()
    }
  }

  // A high-accuracy fix can take the full timeout, and reopening the panel or
  // toggling modes re-enters this — one acquisition at a time
  requestLocation () {
    if (this.locating) return
    if (!navigator.geolocation) return this.locationFailed()
    this.locating = true
    navigator.geolocation.getCurrentPosition(
      (position) => { this.locating = false; this.locationFound(position) },
      () => { this.locating = false; this.locationFailed() },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    )
  }

  locationFound (position) {
    if (this.manualMode) return // they switched to manual entry while we waited
    const { latitude, longitude, accuracy } = position.coords
    this.deviceLocation = position.coords
    this.locate(latitude, longitude, { accuracy })
    this.renderDeviceLocation()
  }

  // Mark where the device actually is, distinct from the pin the user places. Only
  // a real fix is drawn — the org fallback isn't "your location"
  renderDeviceLocation () {
    if (!this.mapLoaded || !this.deviceLocation) return
    const { latitude, longitude, accuracy } = this.deviceLocation
    const data = { type: 'Feature', geometry: { type: 'Point', coordinates: [longitude, latitude] } }
    const radius = groundRadiusStops(accuracy || 0, latitude)

    const source = this.map.getSource('device-location')
    if (source) {
      source.setData(data)
    } else {
      this.map.addSource('device-location', { type: 'geojson', data })
      this.map.addLayer({ id: 'device-accuracy', type: 'circle', source: 'device-location', paint: DEVICE_ACCURACY_PAINT })
      this.map.addLayer({ id: 'device-dot', type: 'circle', source: 'device-location', paint: DEVICE_DOT_PAINT })
    }
    this.map.setPaintProperty('device-accuracy', 'circle-radius', radius)
  }

  locationFailed () {
    if (this.manualMode) return
    // Fall back to the org location; the user drags the map to adjust it
    this.locate(this.orgLatitudeValue, this.orgLongitudeValue, { chosen: false })
  }

  // `chosen` is false for the org fallback: it's somewhere to point the map, not a
  // spot anyone picked, so it stays out of the URL and out of the address fields
  locate (latitude, longitude, { zoom = DEFAULT_ZOOM, accuracy = '', chosen = true } = {}) {
    this.located = true
    this.pinChosen = chosen
    this.setCoordinates(latitude, longitude, accuracy)
    this.pinZoom = zoom
    this.syncMap()
    this.persistMapState()
  }

  // The map settled after the user moved it (or tapped the geolocate button); the
  // fixed pin sits at the centre, so adopt that as the location
  centerAdopted () {
    if (!this.map) return
    const { lat, lng } = this.map.getCenter()
    if (this.centerMoved(lat, lng)) {
      this.pinChosen = true
      this.setCoordinates(lat, lng)
    }
    this.persistMapState() // also captures a zoom change that left the centre put
  }

  // Whether the map centre differs from the coordinates already on the form —
  // true after a user pan, false after our own recenter or a pure zoom
  centerMoved (latitude, longitude) {
    return Math.abs(this.pinLatitude - latitude) > 1e-5 || Math.abs(this.pinLongitude - longitude) > 1e-5
  }

  // The hidden fields are the source of truth for the coordinates
  setCoordinates (latitude, longitude, accuracy = '') {
    this.latitudeTarget.value = latitude
    this.longitudeTarget.value = longitude
    this.accuracyTarget.value = accuracy
    this.enableSubmit()
  }

  get pinLatitude () { return parseFloat(this.latitudeTarget.value) }
  get pinLongitude () { return parseFloat(this.longitudeTarget.value) }
  get pinKey () { return `${this.pinLatitude},${this.pinLongitude}` }

  syncMap () {
    if (!this.hasMapTarget) return
    if (this.map) {
      this.map.easeTo({ center: [this.pinLongitude, this.pinLatitude], zoom: this.pinZoom })
    } else {
      this.buildMap()
    }
  }

  async buildMap () {
    if (this.mapLoading) return
    this.mapLoading = true
    try {
      const maplibregl = await loadMapLibre()
      if (!this.element.isConnected) return

      // Read the coordinates now (not when buildMap was queued) so a fix that
      // arrived while MapLibre was loading is reflected in the initial center
      const center = [this.pinLongitude, this.pinLatitude]
      this.map = new maplibregl.Map({
        container: this.mapTarget,
        style: MAPS_STYLE_URL,
        center,
        zoom: this.pinZoom,
        maxZoom: 18,
        attributionControl: { customAttribution: OSM_ATTRIBUTION }
      })
      this.map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right')
      this.map.addControl(new ExpandControl(), 'top-right')

      // showUserLocation off: we draw the device marker ourselves, and two of them
      // drift apart the moment the control gets a newer fix than our own
      const geolocate = new maplibregl.GeolocateControl({
        positionOptions: { enableHighAccuracy: true },
        showUserLocation: false
      })
      this.map.addControl(geolocate, 'top-right')
      // The control re-centres the map (which moves the pin via moveend); adopt its
      // fresher fix for the marker too
      geolocate.on('geolocate', (position) => {
        this.deviceLocation = position.coords
        this.renderDeviceLocation()
      })

      this.map.on('moveend', () => this.centerAdopted())
      this.map.on('load', () => {
        this.mapLoaded = true
        this.map.resize() // the container may have been collapsed when the map was built
        this.renderDeviceLocation() // a fix that landed before the style was ready
      })
    } catch (error) {
      this.mapUnavailable(error)
    }
  }

  // WebGL/MapLibre can be unavailable (crawlers, headless browsers, disabled GPU,
  // blocked CDN). The coordinates are already stamped, so the form still submits;
  // just reveal a message instead of a blank box
  mapUnavailable (error) {
    console.warn('Parking-notification map failed to render:', error)
    // A control may have thrown after the map was built — dispose it, or its WebGL
    // context and our controls' document listeners outlive the page
    this.map?.remove()
    this.map = null
    if (this.hasMapFrameTarget) this.mapFrameTarget.hidden = true
    if (this.hasMapUnavailableTarget) this.mapUnavailableTarget.hidden = false
  }

  disconnect () {
    this.map?.remove()
    this.map = null
    this.mapLoaded = false // a pending geolocation callback must not touch the removed map
  }

  // The pin + zoom live in the URL so a reload (or shared link) restores them. An
  // unchosen pin isn't worth restoring, and restoring it would make it look chosen
  persistMapState () {
    if (!this.pinChosen) return
    const url = new URL(window.location)
    url.searchParams.set('map_lat', this.pinLatitude.toFixed(6))
    url.searchParams.set('map_lng', this.pinLongitude.toFixed(6))
    url.searchParams.set('map_zoom', (this.map?.getZoom() ?? this.pinZoom).toFixed(2))
    // Revealing the map fires a moveend that changed nothing; skip the no-op write
    if (url.search === window.location.search) return
    window.history.replaceState(window.history.state, '', url)
  }

  get storedMapState () {
    const params = new URLSearchParams(window.location.search)
    const latitude = parseFloat(params.get('map_lat'))
    const longitude = parseFloat(params.get('map_lng'))
    if (Number.isNaN(latitude) || Number.isNaN(longitude)) return null
    const zoom = parseFloat(params.get('map_zoom'))
    return { latitude, longitude, zoom: Number.isNaN(zoom) ? DEFAULT_ZOOM : zoom }
  }

  // Split the pin's coordinates into address parts, to seed the manual-entry
  // fields. Marked before the request so toggling modes doesn't re-ask for a
  // spot we've already looked up. Our endpoint resolves the country and region the
  // way the server does, so what we prefill is what a save would store
  async reverseGeocode () {
    this.geocodedFor = this.pinKey
    // What the fields hold now — anything typed while we wait is theirs, not ours to replace
    const replaceable = new Map([...this.addressGroupTarget.querySelectorAll('[name]')].map((field) => [field, field.value]))
    try {
      const url = `/reverse_geocode?latitude=${this.pinLatitude}&longitude=${this.pinLongitude}`
      // Accept json so a rack-attack 429 comes back as json rather than plain text
      const response = await window.fetch(url, { headers: { Accept: 'application/json' } })
      if (!response.ok) return
      this.geocodedAddress = await response.json()
      this.fillAddress(replaceable)
    } catch { /* leave the fields for them to fill in */ }
  }

  enterManually () {
    this.applyLocationMode(true)
    // Seed from the resolved address while it still describes the pin, without
    // waiting on the network; a pin that has moved gets a fresh geocode instead
    if (this.geocodedFor === this.pinKey) this.fillAddress()
    else if (this.pinChosen) this.reverseGeocode()
    this.enableSubmit()
  }

  // Whether "enter address manually" is the selected mode
  get manualMode () {
    return this.locationModeTargets.some((radio) => radio.value === 'entered' && radio.checked)
  }

  addressField (attribute) {
    return this.addressGroupTarget.querySelector(`[name$='[${attribute}]']`)
  }

  // Write the located place into the AddressGroup fields, which the endpoint names
  // its response after. A blank field is always filled; a field with something in it
  // only when `replaceable` says it still holds what the geocode was asked against.
  fillAddress (replaceable = new Map()) {
    const address = this.geocodedAddress
    if (!address) return
    const country = this.addressField('country_id')
    const countryBefore = country?.value
    Object.entries(address).forEach(([attribute, value]) => {
      const field = this.addressField(attribute)
      if (!field || !value) return
      if (field.value && field.value !== replaceable.get(field)) return
      field.value = value
    })
    // Let AddressGroup swap the state select for the free-text region field. Only on
    // an actual change — it clears the state select for a non-US country
    if (country && country.value !== countryBefore) country.dispatchEvent(new Event('change', { bubbles: true }))
  }

  // Manual entry requires the street and city; the map pin doesn't
  setManualRequired (required) {
    this.element.querySelectorAll("input[name$='[street]'], input[name$='[city]']")
      .forEach((field) => { field.required = required })
  }

  enableSubmit () {
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  toggle (el, visible) { if (el) el.classList.toggle('tw:hidden', !visible) }
}
