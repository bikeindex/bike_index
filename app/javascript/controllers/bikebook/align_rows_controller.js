import { Controller } from '@hotwired/stimulus'

/* global ResizeObserver, MutationObserver, HTMLTableRowElement, requestAnimationFrame, cancelAnimationFrame */

// a row's height is already a minimum, and it ignores min-height
const property = (row) => row instanceof HTMLTableRowElement ? 'height' : 'minHeight'

// Connects to data-controller='bikebook--align-rows'
// Gives each [data-align-row] the height of the tallest sharing its value, so compared cards' rows line up
export default class extends Controller {
  connect () {
    this.resizeObserver = new ResizeObserver(() => this.schedule())
    this.resizeObserver.observe(this.element)
    this.mutationObserver = new MutationObserver(() => this.schedule())
    this.mutationObserver.observe(this.element, { childList: true, subtree: true, characterData: true })
  }

  disconnect () {
    this.resizeObserver.disconnect()
    this.mutationObserver.disconnect()
    cancelAnimationFrame(this.frame)
    this.frame = null
    // lit keeps these elements when another view swaps this controller out
    this.rows().forEach((row) => { row.style[property(row)] = '' })
  }

  rows () {
    return [...this.element.querySelectorAll('[data-align-row]')]
  }

  schedule () {
    this.frame ??= requestAnimationFrame(() => {
      this.frame = null
      this.align()
    })
  }

  align () {
    const rows = this.rows()
    rows.forEach((row) => { row.style[property(row)] = '' })
    const tallest = rows.map((row) => [row.dataset.alignRow, row.getBoundingClientRect().height])
      .reduce((max, [key, height]) => max.set(key, Math.max(max.get(key) ?? 0, height)), new Map())
    rows.forEach((row) => { row.style[property(row)] = `${tallest.get(row.dataset.alignRow)}px` })
  }
}
