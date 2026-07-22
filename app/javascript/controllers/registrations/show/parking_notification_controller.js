import { Controller } from '@hotwired/stimulus'

/* global navigator */

// Connects to data-controller='registrations--show--parking-notification'
// Stamps the new-parking-notification form with the device location (enabling
// submit once found), falling back to manual address entry on error/timeout, and
// toggles the region fields by country. Replaces the legacy
// renderParkingNotificationForm CoffeeScript.
export default class extends Controller {
  static targets = ['latitude', 'longitude', 'accuracy', 'submit', 'waiting',
    'choice', 'addressGroup', 'manualField', 'countrySelect', 'stateField',
    'regionField']

  static values = { usCountryId: Number }

  // The "enter address manually" radio, rendered by UI::Forms::RadioButtonGroup
  get useManualInput () {
    return this.element.querySelector('input[name$="[use_entered_address]"][value="true"]')
  }

  connect () {
    // A panel opened via the URL is already visible when we connect
    if (!this.element.classList.contains('tw:hidden')) this.requestLocation()
  }

  // Fired when the accordion reveals this panel
  requestLocation () {
    if (this.located || this.locating) return
    this.locating = true

    if (!navigator.geolocation) return this.fallback()
    this.fallbackTimer = setTimeout(() => this.fallback(), 45000)
    navigator.geolocation.getCurrentPosition(
      (position) => this.fillLocation(position),
      () => this.fallback(),
      { enableHighAccuracy: true, timeout: 5000, maximumAge: 0 }
    )
  }

  fillLocation (position) {
    clearTimeout(this.fallbackTimer)
    this.located = true
    this.latitudeTarget.value = position.coords.latitude
    this.longitudeTarget.value = position.coords.longitude
    this.accuracyTarget.value = position.coords.accuracy
    this.enableSubmit()
    this.hide(this.waitingTarget)
    this.show(this.choiceTarget)
  }

  fallback () {
    clearTimeout(this.fallbackTimer)
    if (this.located) return

    if (this.hasWaitingTarget) {
      this.waitingTarget.textContent = 'Unable to determine current location automatically'
    }
    this.show(this.choiceTarget)
    if (this.useManualInput) this.useManualInput.checked = true
    this.toggleAddress()
    this.enableSubmit()
  }

  // "Use current location" / "Enter address manually"
  toggleAddress () {
    const manual = Boolean(this.useManualInput?.checked)
    this.toggle(this.addressGroupTarget, manual)
    this.manualFieldTargets.forEach((field) => { field.required = manual })
  }

  // The US uses a region select; other countries a free-text region field
  toggleCountry () {
    const isUs = Number(this.countrySelectTarget.value) === this.usCountryIdValue
    this.toggle(this.stateFieldTarget, isUs)
    this.toggle(this.regionFieldTarget, !isUs)
  }

  enableSubmit () {
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  show (el) { if (el) el.classList.remove('tw:hidden') }
  hide (el) { if (el) el.classList.add('tw:hidden') }
  toggle (el, visible) { if (el) el.classList.toggle('tw:hidden', !visible) }
}
