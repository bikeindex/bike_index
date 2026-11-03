import { Controller } from '@hotwired/stimulus'

/* global IntersectionObserver */

// pages shown of each `key`'s list, which a render in its place shows again
const shown = new Map()

// Connects to data-controller='bikebook--infinite-scroll'
// Shows its hidden pages in order, the next as its sentinel nears the viewport
export default class extends Controller {
  static targets = ['page', 'sentinel']
  static values = { key: String }

  connect () {
    this.pageTargets.slice(0, shown.get(this.keyValue) ?? 1).forEach((page) => { page.hidden = false })
    this.observer = new IntersectionObserver(([entry]) => entry.isIntersecting && this.#next(), { rootMargin: '600px' })
    this.observer.observe(this.sentinelTarget)
  }

  disconnect () {
    this.observer.disconnect()
  }

  #next () {
    const page = this.pageTargets.find((each) => each.hidden)
    if (!page) return this.observer.disconnect()

    page.hidden = false
    shown.set(this.keyValue, this.pageTargets.indexOf(page) + 1)
    // a sentinel still in view reports no change, so it's observed afresh
    this.observer.unobserve(this.sentinelTarget)
    this.observer.observe(this.sentinelTarget)
  }
}
