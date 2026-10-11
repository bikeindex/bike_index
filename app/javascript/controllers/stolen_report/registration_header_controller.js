import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='stolen-report--registration-header'
// The header names the bike being registered as its manufacturer is picked, rather than on the next page
export default class extends Controller {
  static targets = ['title']

  connect () {
    this.update()
  }

  update () {
    const manufacturer = this.element.querySelector('#b_param_manufacturer_id')?.value?.trim()
    if (manufacturer && this.hasTitleTarget) this.titleTarget.textContent = manufacturer
  }
}
