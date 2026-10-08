import { Controller } from '@hotwired/stimulus'

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
    if (!isUs) this.#clearState()
    this.stateInput.required = this.requiredValue && isUs
    this.regionInput.required = this.requiredValue && !isUs
  }

  get isUs () { return Number(this.countryTarget.value) === this.usIdValue }

  // the combobox's visible input, which is what carries required
  get stateInput () { return this.stateTarget.querySelector('[role=combobox]') }

  // Through the gem, so its hidden field and display clear together; the keyup lets the
  // "(CO)" overlay see the selection's gone
  #clearState () {
    const combobox = this.stateTarget.querySelector('.hw-combobox')
    this.application.getControllerForElementAndIdentifier(combobox, 'hw-combobox')?.clear()
    this.stateInput.dispatchEvent(new window.KeyboardEvent('keyup'))
  }

  get regionInput () { return this.regionTarget.querySelector('input') }
}
