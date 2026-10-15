import { Controller } from '@hotwired/stimulus'

/* global localStorage */

const KEY = 'bikebook_tips_dismissed'

// Connects to data-controller='bikebook--tips'
// The empty page's tips, or once they're dismissed the prompt that brings them back. Each swap moves focus to
// what replaced the button pressed
export default class extends Controller {
  static targets = ['tips', 'prompt', 'restore']

  connect () {
    this.#show(!this.#dismissed)
  }

  dismiss () {
    this.#store(() => localStorage.setItem(KEY, '1'))
    this.#show(false)
    this.restoreTarget.focus()
  }

  restore () {
    this.#store(() => localStorage.removeItem(KEY))
    this.#show(true)
    this.tipsTarget.firstElementChild.focus()
  }

  // for the search, which opens its own list, and its filter panel
  browse () {
    this.dispatch('browse')
  }

  filters () {
    this.dispatch('filters')
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
