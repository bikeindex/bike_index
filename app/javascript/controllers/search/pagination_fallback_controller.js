import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='search--pagination-fallback'
//
// The marketplace paginates two ways: links for users without JS, and a lazily
// loaded frame that appends the next page on scroll for everyone else. Only the
// non-JS half survives a page render, so this swaps in the other half.
export default class extends Controller {
  static targets = ['links', 'spinner']

  connect () {
    this.linksTarget.remove()
    if (this.hasSpinnerTarget) this.spinnerTarget.hidden = false
  }
}
