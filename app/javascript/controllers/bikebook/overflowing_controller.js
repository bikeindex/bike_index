import { Controller } from '@hotwired/stimulus'
/* global ResizeObserver */

// Connects to data-controller='bikebook--overflowing'
export default class extends Controller {
  static targets = ['text']

  connect () {
    this.observer = new ResizeObserver(() => this.update())
    this.observer.observe(this.element)
  }

  disconnect () {
    this.observer.disconnect()
  }

  update () {
    this.element.toggleAttribute('data-overflowing', this.textTarget.scrollWidth > this.textTarget.clientWidth)
  }
}
