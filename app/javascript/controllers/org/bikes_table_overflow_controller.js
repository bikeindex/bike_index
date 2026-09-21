import { Controller } from '@hotwired/stimulus'

/* global ResizeObserver */

// Connects to data-controller='org--bikes-table-overflow'
// Flags data-overflowing while the table is wider than its scroll container, which is what
// the frozen view column's shadow keys off. Toggling columns resizes the table, so it's observed too.
export default class extends Controller {
  connect () {
    this.table = this.element.querySelector('table')
    if (!this.table) return

    this.resizeObserver = new ResizeObserver(() => this.#sync())
    this.resizeObserver.observe(this.table.parentElement)
    this.resizeObserver.observe(this.table)
  }

  disconnect () {
    this.resizeObserver?.disconnect()
  }

  #sync () {
    const scroller = this.table.parentElement
    this.element.toggleAttribute('data-overflowing', scroller.scrollWidth > scroller.clientWidth)
  }
}
