import { Controller } from '@hotwired/stimulus'

// The tab row scrolls sideways rather than wrapping, so the active tab is often past the
// right edge on a narrow screen. Scrolls the row itself - scrollIntoView would take the
// page with it.
export default class extends Controller {
  static targets = ['active']

  activeTargetConnected (element) {
    const overflow = this.element.scrollWidth - this.element.clientWidth
    if (overflow <= 0) return

    const centered = element.offsetLeft - (this.element.clientWidth - element.offsetWidth) / 2
    this.element.scrollLeft = Math.min(Math.max(centered, 0), overflow)
  }
}
