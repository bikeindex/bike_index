import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='search--pagination-fallback'
//
// The marketplace ships pagination links whenever the server can't tell whether
// the browser runs JS. It does, so hand the page back to infinite scroll.
export default class extends Controller {
  static targets = ['links']

  connect () {
    // The last page has no frame to scroll into, so its links are the only way out
    const spinner = this.element.querySelector('[data-search-loading]')
    if (!spinner || !this.hasLinksTarget) return

    this.linksTarget.remove()
    spinner.hidden = false
  }
}
