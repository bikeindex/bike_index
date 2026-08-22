import { Controller } from '@hotwired/stimulus'

/* global ResizeObserver, getComputedStyle */

// A scroll container clips whatever sticks out of it vertically and reserves room for a
// scrollbar, so the row only becomes one when the tabs really are wider than it. The active
// tab is then often past the right edge on a narrow screen - scrolls the row itself, since
// scrollIntoView would take the page with it.
export default class extends Controller {
  static targets = ['active', 'row']
  static classes = ['scrollable']

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
    // Assigning scrollLeft clamps to the scrollable range, and no-ops without one
    this.#syncScrollable()
    this.element.scrollLeft = element.offsetLeft - (this.element.clientWidth - element.offsetWidth) / 2
  }

  // The nav's own padding is the gutter it bleeds back in, not room the tabs can grow into,
  // so measure against the content box. A pixel of slack - a max-content row rounds up past
  // a width it visually fits in
  #syncScrollable () {
    const styles = getComputedStyle(this.element)
    const available = this.element.clientWidth - parseFloat(styles.paddingLeft) - parseFloat(styles.paddingRight)

    this.element.classList.toggle(this.scrollableClass, this.rowTarget.scrollWidth > available + 1)
  }
}
