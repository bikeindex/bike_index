import { Controller } from '@hotwired/stimulus'

/* global ResizeObserver, getComputedStyle */

// A scroll container clips whatever sticks out of it vertically - overflow-x forces
// overflow-y auto - so the row only becomes one when the tabs are wider than it. Scrolls the
// row itself to the active tab, since scrollIntoView would take the page with it.
export default class extends Controller {
  static targets = ['active', 'row']

  connect () {
    // The row for the width the tabs need, the nav for the width they have
    this.resizeObserver = new ResizeObserver(() => this.#syncScrollable())
    this.resizeObserver.observe(this.element)
    this.resizeObserver.observe(this.rowTarget)
  }

  disconnect () {
    this.resizeObserver.disconnect()
  }

  activeTargetConnected (element) {
    this.#syncScrollable()
    // Assigning scrollLeft clamps to the scrollable range, and no-ops without one
    this.element.scrollLeft = element.offsetLeft - (this.element.clientWidth - element.offsetWidth) / 2
  }

  // The nav's padding is the gutter twgutter-bleed puts back, not room the tabs can grow into
  #syncScrollable () {
    const styles = getComputedStyle(this.element)
    const available = this.element.clientWidth - parseFloat(styles.paddingLeft) - parseFloat(styles.paddingRight)

    this.element.classList.toggle('tw:overflow-x-auto', this.rowTarget.scrollWidth > Math.ceil(available))
  }
}
