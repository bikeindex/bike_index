import { Controller } from '@hotwired/stimulus'

/* global ResizeObserver, MutationObserver */

// Connects to data-controller='bikebook--align-rows'
// Gives each [data-align-row] the height of the tallest sharing its value, so compared cards' rows line up
export default class extends Controller {
  connect () {
    this.resizeObserver = new ResizeObserver(() => this.align())
    this.resizeObserver.observe(this.element)
    this.mutationObserver = new MutationObserver(() => this.align())
    this.mutationObserver.observe(this.element, { childList: true, subtree: true, characterData: true })
  }

  disconnect () {
    this.resizeObserver.disconnect()
    this.mutationObserver.disconnect()
  }

  align () {
    const rows = [...this.element.querySelectorAll('[data-align-row]')]
    rows.forEach((row) => { row.style.height = '' })
    const tallest = rows.map((row) => [row.dataset.alignRow, row.getBoundingClientRect().height])
      .reduce((max, [key, height]) => max.set(key, Math.max(max.get(key) ?? 0, height)), new Map())
    rows.forEach((row) => { row.style.height = `${tallest.get(row.dataset.alignRow)}px` })
  }
}
