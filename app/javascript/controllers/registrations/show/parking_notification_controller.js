import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'
import { loadMapbox } from 'utils/mapbox'

/* global navigator */

// Connects to data-controller='registrations--show--parking-notification'
// "Set on map" mode drops a draggable pin: it seeds from the browser location
// (falling back to the organization's location), stamps the coordinates onto the
// form, and keeps the pin + zoom in the URL so a reload restores them. "Enter
// address manually" reveals the UI::Forms::AddressGroup fields instead.
const DEFAULT_ZOOM = 15

export default class extends Controller {
  static targets = ['latitude', 'longitude', 'accuracy', 'submit', 'status',
    'statusText', 'statusDot', 'addressGroup', 'useEnteredAddress', 'heading',
    'locationMode', 'kindGroup', 'locationSection', 'mapSection', 'map', 'mapUnavailable']

  static values = {
    notificationHeading: String,
    impoundHeading: String,
    defaultKind: String,
    mapboxKey: String,
    orgLatitude: Number,
    orgLongitude: Number
  }

  // Fired when the accordion reveals this panel; impound preselects that kind,
  // and opening the panel seeds the location so the map appears right away
  applyMode (event) {
    const impound = event.detail?.name === 'impound'
    if (this.hasHeadingTarget) {
      this.headingTarget.textContent = impound ? this.impoundHeadingValue : this.notificationHeadingValue
    }
    const radio = this.element.querySelector(`input[name$="[kind]"][value="${impound ? 'impound_notification' : this.defaultKindValue}"]`)
    if (radio) radio.checked = true
    // Impound preselects the kind, so hide the "Notification because" chooser
    if (this.hasKindGroupTarget) this.toggle(this.kindGroupTarget, !impound)
    this.startLocation()
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
  // controls; a hidden required field would otherwise block submit
  applyRepeat (repeat, duration) {
    if (this.hasLocationSectionTarget) collapse(repeat ? 'hide' : 'show', this.locationSectionTarget, duration)
    if (repeat) {
      this.setManualRequired(false)
      this.enableSubmit()
    } else {
      this.map?.resize()
    }
  }

  // Segmented control: "current" places a pin on the map, "entered" reveals the
  // address fields
  selectLocationMode (event) {
    if (event.target.value === 'entered') {
      this.hide(this.statusTarget)
      this.hide(this.mapSectionTarget)
      this.enterManually()
    } else {
      this.startLocation()
    }
  }

  // Show the map and seed the pin. Once a location has resolved this session the
  // pin is already placed, so just re-reveal the map; otherwise restore it from
  // the URL, or seed the org location and ask the browser for a better fix.
  startLocation () {
    this.setLocationMode('current')
    this.setUseEntered(false)
    this.setManualRequired(false)
    this.hide(this.addressGroupTarget)
    this.show(this.mapSectionTarget)

    if (this.located) {
      this.show(this.statusTarget)
      this.map?.resize()
      return
    }

    const stored = this.storedMapState
    if (stored) {
      this.locate(stored.latitude, stored.longitude, { zoom: stored.zoom })
      this.reverseGeocode(stored.latitude, stored.longitude)
    } else {
      // The org location makes the form submittable at once; the map itself waits
      // for the device fix so it doesn't load tiles it's about to pan away from
      this.setCoordinates(this.orgLatitudeValue, this.orgLongitudeValue)
      this.pinZoom = DEFAULT_ZOOM
      this.requestLocation()
    }
  }

  requestLocation () {
    this.setStatus('Requesting your location…')

    if (!navigator.geolocation) return this.locationFailed()
    navigator.geolocation.getCurrentPosition(
      (position) => this.locationFound(position),
      () => this.locationFailed(),
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    )
  }

  locationFound (position) {
    if (this.manualMode) return // they switched to manual entry while we waited
    const { latitude, longitude, accuracy } = position.coords
    this.locate(latitude, longitude, { zoom: DEFAULT_ZOOM, accuracy })
    this.setStatus('Using your current location', { dot: true })
    this.reverseGeocode(latitude, longitude)
  }

  locationFailed () {
    if (this.manualMode) return
    // The org location already seeded the form, so drop the pin there to drag
    this.locate(this.orgLatitudeValue, this.orgLongitudeValue, { zoom: DEFAULT_ZOOM, persist: false })
    this.setStatus('Drag the pin to set the location', { dot: true })
  }

  // A resolved location: stamp it onto the form and drop/move the pin
  locate (latitude, longitude, { zoom, accuracy = '', persist = true } = {}) {
    if (latitude == null || longitude == null) return
    this.located = true
    this.setCoordinates(latitude, longitude, accuracy)
    if (zoom != null) this.pinZoom = zoom
    this.syncMap()
    if (persist) this.persistMapState()
  }

  // The user placed the pin themselves (drag or map click); the marker is already
  // where they left it, so adopt the coordinates without recentering the map
  pickLocation (latitude, longitude) {
    this.located = true
    this.setCoordinates(latitude, longitude)
    this.persistMapState()
    this.setStatus('Locating the pin…', { dot: true })
    this.reverseGeocode(latitude, longitude)
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

  syncMap () {
    if (!this.hasMapTarget || !this.mapboxKeyValue) return
    if (Number.isNaN(this.pinLatitude) || Number.isNaN(this.pinLongitude)) return
    if (this.map) {
      this.marker.setLngLat([this.pinLongitude, this.pinLatitude])
      this.map.easeTo({ center: [this.pinLongitude, this.pinLatitude], zoom: this.pinZoom ?? this.map.getZoom() })
    } else {
      this.buildMap()
    }
  }

  async buildMap () {
    if (this.mapLoading) return
    this.mapLoading = true
    try {
      const mapboxgl = await loadMapbox()
      if (!this.element.isConnected) return

      // Read the coordinates now (not when buildMap was queued) so a fix that
      // arrived while Mapbox was loading is reflected in the initial center
      const center = [this.pinLongitude, this.pinLatitude]
      mapboxgl.accessToken = this.mapboxKeyValue
      this.map = new mapboxgl.Map({
        container: this.mapTarget,
        style: 'mapbox://styles/mapbox/streets-v11',
        center,
        zoom: this.pinZoom ?? DEFAULT_ZOOM,
        maxZoom: 18
      })
      this.marker = new mapboxgl.Marker({ draggable: true, color: '#dc2626' })
        .setLngLat(center)
        .addTo(this.map)

      this.marker.on('dragend', () => {
        const { lat, lng } = this.marker.getLngLat()
        this.pickLocation(lat, lng)
      })
      this.map.on('click', (event) => {
        this.marker.setLngLat(event.lngLat)
        this.pickLocation(event.lngLat.lat, event.lngLat.lng)
      })
      // Only user pans/zooms carry originalEvent; a programmatic easeTo doesn't
      this.map.on('moveend', (event) => { if (event.originalEvent) this.persistMapState() })
      // The container may have been collapsed when the map was built
      this.map.on('load', () => this.map.resize())
    } catch (error) {
      this.mapUnavailable(error)
    }
  }

  // WebGL/Mapbox can be unavailable (crawlers, headless browsers, disabled GPU,
  // blocked CDN). The coordinates are already stamped, so the form still submits;
  // just reveal a message instead of a blank box
  mapUnavailable (error) {
    console.warn('Parking-notification map failed to render:', error)
    this.map = null
    if (this.hasMapTarget) this.mapTarget.hidden = true
    if (this.hasMapUnavailableTarget) this.mapUnavailableTarget.hidden = false
  }

  disconnect () {
    this.map?.remove()
    this.map = null
  }

  // The pin + zoom live in the URL so a reload (or shared link) restores them
  persistMapState () {
    if (Number.isNaN(this.pinLatitude) || Number.isNaN(this.pinLongitude)) return
    const zoom = this.map ? this.map.getZoom() : this.pinZoom
    const url = new URL(window.location)
    url.searchParams.set('map_lat', this.pinLatitude.toFixed(6))
    url.searchParams.set('map_lng', this.pinLongitude.toFixed(6))
    if (zoom != null) url.searchParams.set('map_zoom', Number(zoom).toFixed(2))
    window.history.replaceState(window.history.state, '', url)
  }

  get storedMapState () {
    const params = new URLSearchParams(window.location.search)
    const latitude = parseFloat(params.get('map_lat'))
    const longitude = parseFloat(params.get('map_lng'))
    if (Number.isNaN(latitude) || Number.isNaN(longitude)) return null
    const zoom = parseFloat(params.get('map_zoom'))
    return { latitude, longitude, zoom: Number.isNaN(zoom) ? undefined : zoom }
  }

  // Reverse-geocode the coordinates into a human-readable place and split address
  async reverseGeocode (latitude, longitude) {
    if (!this.mapboxKeyValue) return
    try {
      const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${longitude},${latitude}.json?access_token=${this.mapboxKeyValue}&types=address&limit=1`
      const response = await window.fetch(url)
      if (!response.ok) return
      const feature = (await response.json()).features?.[0]
      if (!feature) return
      this.geocodedAddress = this.addressFromFeature(feature)
      const place = feature.place_name.replace(/,\s*United States$/, '')
      // In manual entry, seed the fields instead of showing the readout
      if (this.manualMode) this.fillAddress()
      else this.setStatus(place, { dot: true })
    } catch { /* keep the plain status */ }
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
    this.setLocationMode('entered')
    this.setUseEntered(true)
    this.hide(this.mapSectionTarget)
    this.show(this.addressGroupTarget)
    this.fillAddress()
    this.setManualRequired(true)
    this.enableSubmit()
  }

  // Whether "enter address manually" is the selected mode
  get manualMode () {
    return this.locationModeTargets.some((radio) => radio.value === 'entered' && radio.checked)
  }

  // Seed the AddressGroup fields from the located place, without clobbering input.
  // Fields are reached by name (not targets) to stay decoupled from AddressGroup.
  fillAddress () {
    const address = this.geocodedAddress
    if (!address) return
    this.setField('street', address.street)
    this.setField('city', address.city)
    this.setField('postal_code', address.postalCode)
    this.selectCountry(address.country)
    this.selectRegion(address.region)
  }

  setField (attribute, value) {
    if (!value) return
    const field = this.element.querySelector(`[name$='[${attribute}]']`)
    if (field && !field.value) field.value = value
  }

  // Match the country by name and let AddressGroup toggle the state/region field
  selectCountry (name) {
    if (!name) return
    const select = this.element.querySelector("select[name$='[country_id]']")
    if (!select || select.value) return
    const option = [...select.options].find((entry) => entry.text === name)
    if (!option) return
    select.value = option.value
    select.dispatchEvent(new Event('change', { bubbles: true }))
  }

  // A matching US state fills the select; otherwise the free-text region field
  selectRegion (name) {
    if (!name) return
    const stateSelect = this.element.querySelector("select[name$='[region_record_id]']")
    const stateOption = stateSelect && [...stateSelect.options].find((entry) => entry.text === name)
    if (stateOption) {
      if (!stateSelect.value) stateSelect.value = stateOption.value
    } else {
      this.setField('region_string', name)
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

  // The dot only shows once we have a location; other states are plain text
  setStatus (text, { dot = false } = {}) {
    if (!this.hasStatusTarget) return
    if (this.hasStatusTextTarget) this.statusTextTarget.textContent = text
    if (this.hasStatusDotTarget) this.toggle(this.statusDotTarget, dot)
    this.show(this.statusTarget)
  }

  enableSubmit () {
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  show (el) { if (el) el.classList.remove('tw:hidden') }
  hide (el) { if (el) el.classList.add('tw:hidden') }
  toggle (el, visible) { if (el) el.classList.toggle('tw:hidden', !visible) }
}
