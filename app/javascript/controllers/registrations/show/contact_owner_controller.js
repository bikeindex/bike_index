import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='registrations--show--contact-owner'
// Reveals the "contact the owner" message form on click, and records the open
// state in the contact_owner query param so a reload (or shared/returned-from-
// sign-in link) reopens it. Logged-out viewers get a plain sign-in link instead.
export default class extends Controller {
  static targets = ['form', 'trigger']

  connect () {
    // Returning from sign-in (or a tracked link) opens the form without animating in
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
    this.trackExpanded()
  }

  // Reflect the expanded state in the URL without adding a history entry
  trackExpanded () {
    const url = new URL(window.location)
    if (url.searchParams.get('contact_owner') === 'true') return

    url.searchParams.set('contact_owner', 'true')
    window.history.replaceState({}, '', url)
  }
}
