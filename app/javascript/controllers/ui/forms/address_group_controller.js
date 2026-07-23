import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--address-group'
// US addresses use a state <select>; other countries a free-text region field
export default class extends Controller {
  static targets = ['country', 'state', 'region']
  static values = { usId: Number }

  toggleCountry () {
    const isUs = Number(this.countryTarget.value) === this.usIdValue
    this.stateTarget.classList.toggle('tw:hidden', !isUs)
    this.regionTarget.classList.toggle('tw:hidden', isUs)
    if (!isUs) {
      const select = this.stateTarget.querySelector('select')
      if (select) select.value = ''
    }
  }
}
