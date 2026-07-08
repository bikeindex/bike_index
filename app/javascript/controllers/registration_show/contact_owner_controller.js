import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='registration-show--contact-owner'
// Reveals the "contact the owner" message form on click. A viewer returning from
// sign-in (via the contact_owner query param) gets the form opened automatically.
// Logged-out viewers get a plain sign-in link instead - no form is rendered.
export default class extends Controller {
  static targets = ['form', 'trigger']

  connect () {
    if (new URLSearchParams(window.location.search).has('contact_owner')) {
      this.open()
    }
  }

  reveal (event) {
    event.preventDefault()
    this.open()
  }

  open () {
    if (!this.hasFormTarget) return
    this.formTarget.hidden = false
    if (this.hasTriggerTarget) this.triggerTarget.hidden = true
  }
}
