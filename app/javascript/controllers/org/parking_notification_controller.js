import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='org--parking-notification'
// Reveals the "new parking notification" form, requests the device location to
// fill the hidden lat/lng fields (falling back to manual address entry), and
// toggles the manual address fields and US-state vs region inputs. Replaces the
// legacy jQuery handlers in bikes/show.coffee that relied on Bootstrap's
// (no-longer-loaded) collapse plugin and `$(document).ready`.
export default class extends Controller {
  static targets = [
    'openButton', 'fields', 'latitude', 'longitude', 'accuracy', 'submit',
    'waiting', 'locationRadios', 'manualRadio', 'addressGroup', 'stateSelect', 'regionText', 'fileName'
  ]

  static values = { unitedStatesId: Number }

  connect () {
    // The form renders open after a validation error — start locating right away.
    if (!this.fieldsTarget.classList.contains('tw:hidden!')) this.requestLocation()
  }

  disconnect () {
    clearTimeout(this.fallbackTimeout)
  }

  open (event) {
    event.preventDefault()
    collapse('hide', this.openButtonTarget)
    collapse('show', this.fieldsTarget)
    this.requestLocation()
  }

  requestLocation () {
    if (this.locating) return
    this.locating = true
    this.waitingOnLocation = true
    if (!navigator.geolocation) return this.fallbackToManualAddress()
    // Fall back to manual entry if the device never returns a location.
    this.fallbackTimeout = setTimeout(() => this.fallbackToManualAddress(), 45000)
    navigator.geolocation.getCurrentPosition(
      position => this.fillInLocation(position),
      error => { console.log(error); this.fallbackToManualAddress() },
      { enableHighAccuracy: true, timeout: 5000, maximumAge: 0 }
    )
  }

  fillInLocation (position) {
    this.waitingOnLocation = false
    clearTimeout(this.fallbackTimeout)
    this.latitudeTarget.value = position.coords.latitude
    this.longitudeTarget.value = position.coords.longitude
    this.accuracyTarget.value = position.coords.accuracy
    this.submitTarget.disabled = false
    collapse('hide', this.waitingTarget)
    collapse('show', this.locationRadiosTarget)
  }

  fallbackToManualAddress () {
    if (!this.waitingOnLocation) return
    this.waitingOnLocation = false
    clearTimeout(this.fallbackTimeout)
    this.waitingTarget.textContent = 'Unable to determine current location automatically'
    this.manualRadioTarget.checked = true
    collapse('show', this.addressGroupTarget)
    this.submitTarget.disabled = false
  }

  toggleAddress () {
    collapse(this.manualRadioTarget.checked ? 'show' : 'hide', this.addressGroupTarget)
  }

  toggleCountry (event) {
    const isUnitedStates = event.target.value === `${this.unitedStatesIdValue}`
    this.stateSelectTarget.classList.toggle('unhidden', isUnitedStates)
    this.regionTextTarget.classList.toggle('unhidden', !isUnitedStates)
  }

  updateFileName (event) {
    const file = event.target.files[0]
    if (file) this.fileNameTarget.textContent = file.name
  }
}
