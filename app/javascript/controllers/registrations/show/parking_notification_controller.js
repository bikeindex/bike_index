import { Controller } from '@hotwired/stimulus'

/* global navigator */

// Connects to data-controller='registrations--show--parking-notification'
// Requests the device location when the panel opens (and on the button click),
// stamps it onto the form and enables submit; also supports entering the address
// manually via the UI::Forms::AddressGroup fields.
export default class extends Controller {
  static targets = ['latitude', 'longitude', 'accuracy', 'submit', 'status',
    'statusText', 'statusDot', 'addressGroup', 'useEnteredAddress', 'heading',
    'locationMode']

  static values = {
    notificationHeading: String,
    impoundHeading: String,
    defaultKind: String,
    mapboxKey: String
  }

  // Fired when the accordion reveals this panel; impound preselects that kind,
  // and opening the panel requests the location so the browser prompts right away
  applyMode (event) {
    const impound = event.detail?.mode === 'impound'
    if (this.hasHeadingTarget) {
      this.headingTarget.textContent = impound ? this.impoundHeadingValue : this.notificationHeadingValue
    }
    const radio = this.element.querySelector(`input[name$="[kind]"][value="${impound ? 'impound_notification' : this.defaultKindValue}"]`)
    if (radio) radio.checked = true
    this.requestLocation()
  }

  // Segmented control: "current" geolocates, "entered" reveals the address fields
  selectLocationMode (event) {
    if (event.target.value === 'entered') {
      this.hide(this.statusTarget) // the current-location readout is irrelevant in manual entry
      this.enterManually()
    } else {
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
    this.latitudeTarget.value = position.coords.latitude
    this.longitudeTarget.value = position.coords.longitude
    this.accuracyTarget.value = position.coords.accuracy
    this.setLocationMode('current')
    this.setUseEntered(false)
    this.hide(this.addressGroupTarget)
    this.setManualRequired(false)
    this.setStatus('Using your current location', { dot: true })
    this.reverseGeocode(position.coords.latitude, position.coords.longitude)
    this.enableSubmit()
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
      else this.setStatus(`Using your current location · ${place}`, { dot: true })
    } catch { /* keep the plain "current location" status */ }
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

  locationFailed () {
    this.setStatus("Couldn't determine your location — enter the address below")
    this.enterManually()
  }

  enterManually () {
    this.setLocationMode('entered')
    this.setUseEntered(true)
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

  // Manual entry requires the street and city; geolocation doesn't
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
