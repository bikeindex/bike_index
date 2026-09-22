import { Controller } from '@hotwired/stimulus'

/* global ResizeObserver */

// Connects to data-controller='org--bikes-table-overflow'
// Flags data-overflowing while the table is wider than its scroll container, which is what
// the frozen view column's shadow keys off, and data-scrolled-end once it's scrolled all the way,
// which drops the right edge's. Toggling columns resizes the table, so it's observed too.
export default class extends Controller {
  connect () {
    this.table = this.element.querySelector('table')
    if (!this.table) return

    this.scroller = this.table.parentElement
    this.boundSync = () => this.#sync()
    this.scroller.addEventListener('scroll', this.boundSync, { passive: true })
    this.resizeObserver = new ResizeObserver(this.boundSync)
    this.resizeObserver.observe(this.scroller)
    this.resizeObserver.observe(this.table)
  }

  disconnect () {
    this.resizeObserver?.disconnect()
    this.scroller?.removeEventListener('scroll', this.boundSync)
  }

  #sync () {
    const { scrollWidth, clientWidth, scrollLeft } = this.scroller
    const overflowing = scrollWidth > clientWidth
    this.element.toggleAttribute('data-overflowing', overflowing)
    // Scroll positions come back fractional, so within a pixel counts as the end
    this.element.toggleAttribute('data-scrolled-end', overflowing && scrollLeft + clientWidth >= scrollWidth - 1)
  }
}
