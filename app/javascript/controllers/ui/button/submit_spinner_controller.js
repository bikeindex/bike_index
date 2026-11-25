import { Controller } from '@hotwired/stimulus'

/* global window */

// Connects to data-controller="ui--button--submit-spinner" (on a submit button - rendered
// by UI::Button spinner: true). Once the button's form actually submits
// (native validation has passed), disables the button and reveals its spinner.
export default class extends Controller {
  static targets = ['spinner']

  connect () {
    // Cached, because a detached button's .form is null - disconnect couldn't find it to unsubscribe
    this.form = this.element.form
    this.form?.addEventListener('submit', this.start)
    // A bfcache restore resumes the page without reconnecting, so the reset
    // needs pageshow as well as connect (which covers Turbo cache restores)
    window.addEventListener('pageshow', this.reset)
    // For a submit that ended without the page going anywhere - see register--retry
    this.element.addEventListener('spinner:reset', this.reset)
    this.reset()
  }

  disconnect () {
    this.form?.removeEventListener('submit', this.start)
    this.form = null
    window.removeEventListener('pageshow', this.reset)
    this.element.removeEventListener('spinner:reset', this.reset)
  }

  start = () => {
    this.element.dataset.submitted = 'true'
    this.element.disabled = true
    this.spinnerTarget.classList.remove('tw:hidden')
  }

  // Clear the submitted state a cached page was stored with
  reset = () => {
    if (!this.element.dataset.submitted) return

    delete this.element.dataset.submitted
    this.element.disabled = false
    this.spinnerTarget.classList.add('tw:hidden')
  }
}
