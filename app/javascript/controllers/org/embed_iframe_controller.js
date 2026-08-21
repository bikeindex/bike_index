import { Controller } from '@hotwired/stimulus'

/* global ResizeObserver */

// TODO: #4185 - remove when removing the legacy org new bike iframe
// Connects to data-controller='org--embed-iframe'
// Sizes the frame to what it renders, rather than to the stylesheet's fixed height
export default class extends Controller {
  // The frame may have loaded before this connected, so fit rather than waiting on load
  connect () {
    this.fit()
  }

  disconnect () {
    this.observer?.disconnect()
  }

  fit () {
    const body = this.element.contentDocument?.body
    if (!body) return

    // body rather than documentElement, which can't report less than the height we just
    // gave the frame - so a form that collapses would never shrink it back
    this.observer?.disconnect()
    this.observer = new ResizeObserver(() => this.setHeight(body))
    this.observer.observe(body)
    this.setHeight(body)
  }

  // Only when it moves: the write invalidates the parent's layout, and comes back here
  // through the observer
  setHeight (body) {
    const height = `${body.scrollHeight}px`
    if (height !== this.element.style.height) this.element.style.height = height
  }
}
