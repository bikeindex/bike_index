import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='registration-show--contact-owner'
// Reveals the "contact the owner" message form on click. Logged-out viewers are
// redirected to sign-in instead (redirectValue), and are returned with the form
// already open via the contact_owner query param - mirroring legacy bikes/show.
export default class extends Controller {
  static targets = ['form', 'trigger']
  static values = { redirect: String }

  connect () {
    if (new URLSearchParams(window.location.search).has('contact_owner')) {
      this.open()
    }
  }

  reveal (event) {
    event.preventDefault()
    if (this.redirectValue) {
      window.location = this.redirectValue
      return
    }
    this.open()
  }

  open () {
    this.formTarget.hidden = false
    if (this.hasTriggerTarget) this.triggerTarget.hidden = true
  }
}
