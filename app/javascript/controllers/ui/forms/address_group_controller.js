import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--address-group'
// US addresses use a state <select>; other countries a free-text region field
export default class extends Controller {
  static targets = ['country', 'state', 'region']
  static values = { usId: Number }

  toggleCountry () {
    const isUs = this.isUs
    // Whichever of the pair is showing carries the required attribute - the browser
    // won't submit a form with a hidden required field, and can't focus it to say why.
    // Blanked rather than disabled, so the country it no longer matches is cleared
    const required = this.stateSelect.required || this.regionInput.required
    this.stateTarget.classList.toggle('tw:hidden', !isUs)
    this.regionTarget.classList.toggle('tw:hidden', isUs)
    if (!isUs) this.stateSelect.value = ''
    this.stateSelect.required = required && isUs
    this.regionInput.required = required && !isUs
  }

  get isUs () { return Number(this.countryTarget.value) === this.usIdValue }

  get stateSelect () { return this.stateTarget.querySelector('select') }

  get regionInput () { return this.regionTarget.querySelector('input') }
}
