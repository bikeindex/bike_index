import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='registration-show--contact-owner'
// Reveals the "contact the owner" message form on click. A viewer returning from
// sign-in (via the contact_owner query param) gets the form opened automatically.
// Logged-out viewers get a plain sign-in link instead - no form is rendered.
export default class extends Controller {
  static targets = ['form', 'trigger']

  connect () {
    // Returning from sign-in opens the form without animating in
    if (new URLSearchParams(window.location.search).has('contact_owner')) {
      this.open(0)
    }
  }

  reveal (event) {
    event.preventDefault()
    this.open()
  }

  open (duration = 200) {
    if (!this.hasFormTarget) return
    collapse('show', this.formTarget, duration)
    if (this.hasTriggerTarget) collapse('hide', this.triggerTarget, duration)
  }
}
