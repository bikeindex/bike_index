import { Controller } from '@hotwired/stimulus'

// The tab row scrolls sideways rather than wrapping, so the active tab is often past the
// right edge on a narrow screen. Scrolls the row itself - scrollIntoView would take the
// page with it.
export default class extends Controller {
  static targets = ['active']

  activeTargetConnected (element) {
    // Assigning scrollLeft clamps to the scrollable range, and no-ops without one
    this.element.scrollLeft = element.offsetLeft - (this.element.clientWidth - element.offsetWidth) / 2
  }
}
