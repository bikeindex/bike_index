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
    this.tipsTarget.querySelector('[tabindex="-1"]').focus()
  }

  // the search's own panel, which sits outside this controller
  openFilters () {
    const toggle = document.querySelector('[aria-controls="vehicle-filters"]')
    if (toggle.getAttribute('aria-expanded') === 'false') toggle.click()
    document.getElementById('vehicle-filters').querySelector('input:not([type="hidden"])')?.focus()
  }

  // after this click, which would otherwise close the list as a click outside it
  browse () {
    const field = document.querySelector('[data-bikebook--focus-shortcut-target="field"]')
    setTimeout(() => {
      field.focus()
      field.click()
    })
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
