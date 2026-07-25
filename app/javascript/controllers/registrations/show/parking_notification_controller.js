import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'
import { ExpandControl, groundRadiusStops, loadMapLibre, OSM_ATTRIBUTION } from 'utils/maplibre'

/* global navigator */

// Connects to data-controller='registrations--show--parking-notification'
// "Set on map" mode shows a map under a fixed centre pin: it seeds from the
// browser location (falling back to the organization's location), stamps the
// coordinates onto the form, and keeps the pin + zoom in the URL so a reload
// restores them. Moving the map moves the pin. "Enter address manually" reveals
// the UI::Forms::AddressGroup fields instead. Tiles come from our self-hosted
// MapLibre basemap; the mapboxKey is only for reverse-geocoding the pin.
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
    mapboxKey: String,
    styleUrl: String,
    orgLatitude: Number,
    orgLongitude: Number
  }

  // Fired when the accordion reveals this panel; impound preselects that kind
  applyMode (event) {
    const impound = event.detail?.name === 'impound'
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

  selectRepeat (event) {
    this.applyRepeat(event.target.value === 'true', 200)
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
    this.setLocationMode(manual ? 'entered' : 'current')
    this.setUseEntered(manual)
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
    if (!this.hasMapTarget || !this.styleUrlValue) return
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
        style: this.styleUrlValue,
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
  // spot we've already looked up
  async reverseGeocode () {
    if (!this.mapboxKeyValue) return
    this.geocodedFor = this.pinKey
    try {
      const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${this.pinLongitude},${this.pinLatitude}.json?access_token=${this.mapboxKeyValue}&types=address&limit=1`
      const response = await window.fetch(url)
      if (!response.ok) return
      const feature = (await response.json()).features?.[0]
      if (!feature) return
      this.geocodedAddress = this.addressFromFeature(feature)
      // The pin has moved since the fields were seeded, so whatever they hold
      // describes the old spot — replace it
      this.fillAddress({ overwrite: true })
    } catch { /* leave the fields for them to fill in */ }
  }

  // Split a Mapbox feature into street/city/region/postal/country parts
  addressFromFeature (feature) {
    const context = feature.context || []
    const part = (prefix) => context.find((entry) => entry.id.startsWith(`${prefix}.`))?.text
    return {
      street: [feature.address, feature.text].filter(Boolean).join(' '),
      city: part('place') || part('locality'),
      region: part('region'),
      postalCode: part('postcode'),
      country: part('country')
    }
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

  // Write the located place into the AddressGroup fields. Without `overwrite` it
  // only fills blanks, so it can't clobber what they typed. Fields are reached by
  // name (not targets) to stay decoupled from AddressGroup.
  fillAddress ({ overwrite = false } = {}) {
    const address = this.geocodedAddress
    if (!address) return
    this.setField('street', address.street, overwrite)
    this.setField('city', address.city, overwrite)
    this.setField('postal_code', address.postalCode, overwrite)
    this.selectCountry(address.country, overwrite)
    this.selectRegion(address.region, overwrite)
  }

  setField (attribute, value, overwrite) {
    if (!value) return
    const field = this.element.querySelector(`[name$='[${attribute}]']`)
    if (field && (overwrite || !field.value)) field.value = value
  }

  // Match the country by name and let AddressGroup toggle the state/region field
  selectCountry (name, overwrite) {
    if (!name) return
    const select = this.element.querySelector("select[name$='[country_id]']")
    if (!select || (select.value && !overwrite)) return
    const option = [...select.options].find((entry) => entry.text === name)
    if (!option) return
    select.value = option.value
    select.dispatchEvent(new Event('change', { bubbles: true }))
  }

  // A matching US state fills the select; otherwise the free-text region field
  selectRegion (name, overwrite) {
    if (!name) return
    const stateSelect = this.element.querySelector("select[name$='[region_record_id]']")
    const stateOption = stateSelect && [...stateSelect.options].find((entry) => entry.text === name)
    if (stateOption) {
      if (overwrite || !stateSelect.value) stateSelect.value = stateOption.value
    } else {
      this.setField('region_string', name, overwrite)
    }
  }

  // Manual entry requires the street and city; the map pin doesn't
  setManualRequired (required) {
    this.element.querySelectorAll("input[name$='[street]'], input[name$='[city]']")
      .forEach((field) => { field.required = required })
  }

  // Reflect programmatic mode changes (geolocation success/failure) in the radios
  setLocationMode (value) {
    this.locationModeTargets.forEach((radio) => { radio.checked = radio.value === value })
  }

  setUseEntered (value) {
    if (this.hasUseEnteredAddressTarget) this.useEnteredAddressTarget.value = value
  }

  enableSubmit () {
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  toggle (el, visible) { if (el) el.classList.toggle('tw:hidden', !visible) }
}
