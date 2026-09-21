import { Controller } from '@hotwired/stimulus'

/* global ResizeObserver */

// Connects to data-controller='org--bikes-table-overflow'
// Flags data-overflowing while the table needs more room than it has, which the frozen view
// column's shadow keys off - and the search page's card, which bleeds to the page edges on it.
// The bleed widens the table, so overflow is judged against the width from before it: judged
// on the widened table, it would fit, drop the bleed, and overflow again.
export default class extends Controller {
  connect () {
    this.table = this.element.querySelector('table')
    if (!this.table) return

    this.resizeObserver = new ResizeObserver(() => this.#sync())
    this.resizeObserver.observe(this.element)
    this.resizeObserver.observe(this.table)
  }

  disconnect () {
    this.resizeObserver?.disconnect()
  }

  #sync () {
    const width = this.element.clientWidth
    const bled = this.element.hasAttribute('data-overflowing')
    if (!bled) {
      this.unbledWidth = width
    } else {
      this.bleed ??= width - this.unbledWidth
    }
    this.element.toggleAttribute('data-overflowing', this.#minTableWidth() > width - (bled ? this.bleed : 0))
  }

  // The table stretches to fill its scroller, so its own width can't say whether it fits
  #minTableWidth () {
    const { width, minWidth } = this.table.style
    Object.assign(this.table.style, { width: '0', minWidth: '0' })
    const minTableWidth = this.table.offsetWidth
    Object.assign(this.table.style, { width, minWidth })
    return minTableWidth
  }
}
