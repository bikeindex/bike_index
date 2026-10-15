import { Controller } from '@hotwired/stimulus'

/* global ResizeObserver, MutationObserver */
// Connects to data-controller='bikebook--align-rows'
// Gives each [data-align-row] the height of the tallest sharing its value, so compared cards' rows line up
export default class extends Controller {
  connect () {
    const align = () => this.align()
    this.observers = [new ResizeObserver(align), new MutationObserver(align)]
    this.observers[0].observe(this.element)
    this.observers[1].observe(this.element, { childList: true, subtree: true, characterData: true })
  }

  disconnect () {
    this.observers.forEach((observer) => observer.disconnect())
  }

  align () {
    const rows = [...this.element.querySelectorAll('[data-align-row]')]
    rows.forEach((row) => { row.style.height = '' })
    const heights = rows.map((row) => row.getBoundingClientRect().height)
    const tallest = rows.reduce((max, row, index) => max.set(row.dataset.alignRow, Math.max(max.get(row.dataset.alignRow) ?? 0, heights[index])), new Map())
    rows.forEach((row) => { row.style.height = `${tallest.get(row.dataset.alignRow)}px` })
  }
}
