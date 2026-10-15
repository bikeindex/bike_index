import { Controller } from '@hotwired/stimulus'

/* global ResizeObserver */

// Connects to data-controller='bikebook--read-more'
// Opens and closes a clamped text, whose button shows only while the clamp hides some of it
export default class extends Controller {
  static targets = ['text', 'button']

  connect () {
    this.observer = new ResizeObserver(() => this.#measure())
    this.observer.observe(this.textTarget)
  }

  disconnect () {
    this.observer.disconnect()
  }

  toggle () {
    this.buttonTarget.setAttribute('aria-expanded', this.element.toggleAttribute('data-expanded'))
  }

  // an open text has nothing clamped to measure
  #measure () {
    if ('expanded' in this.element.dataset) return

    this.buttonTarget.hidden = this.textTarget.scrollHeight <= this.textTarget.clientHeight
  }
}
