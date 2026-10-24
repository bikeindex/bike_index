import { Controller } from '@hotwired/stimulus'

/* global IntersectionObserver */

// Connects to data-controller='bikebook--infinite-scroll'
// Shows its hidden pages in order, the next as its sentinel nears the viewport
export default class extends Controller {
  static targets = ['page', 'sentinel']

  connect () {
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
    // a sentinel still in view reports no change, so it's observed afresh
    this.observer.unobserve(this.sentinelTarget)
    this.observer.observe(this.sentinelTarget)
  }
}
