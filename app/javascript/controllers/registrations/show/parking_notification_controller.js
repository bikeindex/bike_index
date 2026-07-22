import { Controller } from '@hotwired/stimulus'

/* global navigator */

// Connects to data-controller='registrations--show--parking-notification'
// Requests the device location on demand (so the browser prompts on the button
// click), stamps it onto the form and enables submit; also supports entering the
// address manually, and toggles the region fields by country.
export default class extends Controller {
  static targets = ['latitude', 'longitude', 'accuracy', 'submit', 'status',
    'addressGroup', 'manualField', 'useEnteredAddress', 'countrySelect',
    'stateField', 'regionField', 'heading']

  static values = {
    usCountryId: Number,
    notificationHeading: String,
    impoundHeading: String,
    defaultKind: String
  }

  // Fired when the accordion reveals this panel; impound preselects that kind
  applyMode (event) {
    const impound = event.detail?.mode === 'impound'
    if (this.hasHeadingTarget) {
      this.headingTarget.textContent = impound ? this.impoundHeadingValue : this.notificationHeadingValue
    }
    const radio = this.element.querySelector(`input[name$="[kind]"][value="${impound ? 'impound_notification' : this.defaultKindValue}"]`)
    if (radio) radio.checked = true
  }

  requestLocation (event) {
    if (event) event.preventDefault()
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
    this.setUseEntered(false)
    this.hide(this.addressGroupTarget)
    this.manualFieldTargets.forEach((field) => { field.required = false })
    this.setStatus('Using your current location')
    this.enableSubmit()
  }

  locationFailed () {
    this.setStatus("Couldn't determine your location — enter the address below")
    this.enterManually()
  }

  enterManually (event) {
    if (event) event.preventDefault()
    this.setUseEntered(true)
    this.show(this.addressGroupTarget)
    this.manualFieldTargets.forEach((field) => { field.required = true })
    this.enableSubmit()
  }

  // The US uses a region select; other countries a free-text region field
  toggleCountry () {
    const isUs = Number(this.countrySelectTarget.value) === this.usCountryIdValue
    this.toggle(this.stateFieldTarget, isUs)
    this.toggle(this.regionFieldTarget, !isUs)
  }

  setUseEntered (value) {
    if (this.hasUseEnteredAddressTarget) this.useEnteredAddressTarget.value = value
  }

  setStatus (text) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = text
    this.show(this.statusTarget)
  }

  enableSubmit () {
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  show (el) { if (el) el.classList.remove('tw:hidden') }
  hide (el) { if (el) el.classList.add('tw:hidden') }
  toggle (el, visible) { if (el) el.classList.toggle('tw:hidden', !visible) }
}
