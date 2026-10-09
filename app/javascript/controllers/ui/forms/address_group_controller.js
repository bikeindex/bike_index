import { Controller } from '@hotwired/stimulus'
import { clearCombobox } from 'utils/hw_combobox_patch'

// Connects to data-controller='ui--forms--address-group'
// US addresses use a state combobox; other countries a free-text region field
export default class extends Controller {
  static targets = ['country', 'state', 'region']
  static values = { usId: Number, required: Boolean }

  toggleCountry () {
    const isUs = this.isUs
    // Whichever of the pair is showing carries the required attribute - the browser
    // won't submit a form with a hidden required field, and can't focus it to say why.
    // Blanked rather than disabled, so the country it no longer matches is cleared
    this.stateTarget.classList.toggle('tw:hidden', !isUs)
    this.regionTarget.classList.toggle('tw:hidden', isUs)
    if (!isUs) clearCombobox(this.stateTarget.querySelector('.hw-combobox'))
    this.stateInput.required = this.requiredValue && isUs
    this.regionInput.required = this.requiredValue && !isUs
  }

  get isUs () { return Number(this.countryTarget.value) === this.usIdValue }

  // the combobox's visible input, which is what carries required
  get stateInput () { return this.stateTarget.querySelector('[role=combobox]') }

  get regionInput () { return this.regionTarget.querySelector('input') }
}
