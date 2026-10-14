import { Controller } from '@hotwired/stimulus'

/* global localStorage */

const KEY = 'bikebook_tips_dismissed'

// Connects to data-controller='bikebook--tips'
// The empty page's tips, or once they're dismissed the prompt that brings them back
export default class extends Controller {
  static targets = ['tips', 'prompt']

  connect () {
    this.#show(!this.#dismissed)
  }

  dismiss () {
    this.#store(() => localStorage.setItem(KEY, '1'))
    this.#show(false)
  }

  restore () {
    this.#store(() => localStorage.removeItem(KEY))
    this.#show(true)
  }

  // the search's own panel, which sits outside this controller
  openFilters () {
    document.querySelector('[aria-controls="vehicle-filters"][aria-expanded="false"]')?.click()
  }

  #show (tips) {
    this.tipsTarget.hidden = !tips
    this.promptTarget.hidden = tips
  }

  get #dismissed () {
    try {
      return localStorage.getItem(KEY) === '1'
    } catch {
      return false
    }
  }

  #store (write) {
    try {
      write()
    } catch {}
  }
}
