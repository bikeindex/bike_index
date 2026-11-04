import { Controller } from '@hotwired/stimulus'

/* global ResizeObserver */

// Connects to data-controller='ui--table-overflow'
// Flags data-overflowing while the table is wider than its scroll container, which is what
// UI::TableInCard's frozen column shadow keys off, and data-scrolled-end once it's scrolled all the way,
// which drops the right edge's. Toggling columns resizes the table or its headers, so they're observed too.
// A card's row, marked data-table-bleed, is set true while the table is wider than the card.
export default class extends Controller {
  connect () {
    this.table = this.element.querySelector('table')
    if (!this.table) return

    this.scroller = this.table.parentElement
    this.row = this.element.closest('[data-table-bleed]')
    this.boundSyncScroll = () => this.#syncScroll()
    this.scroller.addEventListener('scroll', this.boundSyncScroll, { passive: true })
    this.resizeObserver = new ResizeObserver(() => this.#sync())
    const observed = [this.scroller, this.table, ...this.table.querySelectorAll('th')]
    observed.forEach(element => this.resizeObserver.observe(element))
  }

  disconnect () {
    this.resizeObserver?.disconnect()
    this.scroller?.removeEventListener('scroll', this.boundSyncScroll)
  }

  // Bleeding gives the table room, so overflow can't decide it: a table that only just overflowed would
  // then fit, and flip back. The row's width and the table's minimum don't move with it
  #sync () {
    if (this.row) this.row.dataset.tableBleed = this.#minimumTableWidth() > this.row.clientWidth - CARD_BORDERS_WIDTH
    this.#syncScroll()
  }

  #syncScroll () {
    const { scrollWidth, clientWidth, scrollLeft } = this.scroller
    const overflowing = scrollWidth > clientWidth
    this.element.toggleAttribute('data-overflowing', overflowing)
    // Scroll positions come back fractional, so within a pixel counts as the end
    this.element.toggleAttribute('data-scrolled-end', overflowing && scrollLeft + clientWidth >= scrollWidth - 1)
  }

  // A table that fits stretches to its container, so its own width doesn't say. Restored before it paints
  #minimumTableWidth () {
    const { style } = this.table
    const inlineStyle = style.cssText
    style.minWidth = '0'
    style.width = 'min-content'
    const width = this.table.offsetWidth
    style.cssText = inlineStyle
    return width
  }
}

const CARD_BORDERS_WIDTH = 2
