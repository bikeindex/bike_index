import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='search--pagination-fallback'
//
// The marketplace paginates two ways and renders both, since only the non-JS
// half survives a page render. This swaps in the other one.
export default class extends Controller {
  static targets = ['links', 'spinner']

  connect () {
    this.linksTarget.remove()
    if (this.hasSpinnerTarget) this.spinnerTarget.hidden = false
  }
}
