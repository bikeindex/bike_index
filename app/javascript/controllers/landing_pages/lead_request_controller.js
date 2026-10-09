import { Controller } from '@hotwired/stimulus'

/* global Event */

// Connects to data-controller='landing-pages--lead-request'
// Sits inside the form-persist form, so it connects after it and its deferred default
// runs after a draft's choice is restored
export default class extends Controller {
  static targets = ['radio']

  connect () {
    this.defaultTimer = setTimeout(() => {
      if (!this.radioTargets.some(radio => radio.checked)) this.radioTargets[0].checked = true
    }, 0)
  }

  disconnect () {
    clearTimeout(this.defaultTimer)
  }

  // A link anywhere on the page to the form says which request it's for
  choose (event) {
    const link = event.target.closest('[data-lead-request]')
    if (!link) return

    this.radioTargets.forEach(radio => { radio.checked = radio.value === link.dataset.leadRequest })
    const chosen = this.radioTargets.find(radio => radio.checked)
    if (!chosen) return

    // Setting checked fires nothing, so the draft wouldn't hear the choice
    chosen.dispatchEvent(new Event('input', { bubbles: true }))
    chosen.focus({ preventScroll: true })
  }
}
