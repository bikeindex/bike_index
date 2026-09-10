import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='csrf-refresh'
// The registration show page fragment-caches its forms (see
// Pages::Registrations::Show::Wrapper), so a form's embedded authenticity_token can be a
// stale, session-scoped token captured when the cache was populated. Overwrite it
// on connect with the fresh per-request token from the csrf-token meta tag (which
// the layout renders outside the cache) so the submission validates for this
// session. Without this the forms rely on legacy jQuery-UJS's refreshCSRFTokens,
// which the Stimulus redesign shouldn't depend on.
export default class extends Controller {
  connect () {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    if (!token) return
    this.element.querySelectorAll('input[name="authenticity_token"]').forEach((input) => {
      input.value = token
    })
  }
}
