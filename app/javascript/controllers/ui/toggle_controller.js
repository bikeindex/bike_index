import { Controller } from '@hotwired/stimulus'

/* global ResizeObserver, requestAnimationFrame */

// Connects to data-controller='ui--toggle'
// A track wraps, so its widest segment rather than its whole row is what it asks of its ancestors. Once any segment has
// wrapped, every one takes a line of its own
export default class extends Controller {
  connect () {
    this.#fit()
    // The parent for the width it has, the track for the width its segments need, once it's shown or its font loads.
    // A frame later, since stacking resizes both of what's being observed
    this.resizeObserver = new ResizeObserver(() => requestAnimationFrame(() => this.#fit()))
    this.resizeObserver.observe(this.element)
    this.resizeObserver.observe(this.element.parentElement)
  }

  disconnect () {
    this.resizeObserver.disconnect()
  }

  #fit () {
    this.element.classList.remove('tw:flex-col')
    const [first, ...others] = this.element.children
    this.element.classList.toggle('tw:flex-col', others.some((segment) => segment.offsetTop !== first.offsetTop))
  }
}
