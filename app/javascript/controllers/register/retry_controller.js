import { Controller } from '@hotwired/stimulus'

/* global setTimeout, clearTimeout */

// Connects to data-controller='register--retry'
//
// Every step submits through Turbo, so a throttled or restarting server comes
// back as a response we can take over rather than an error page the rider lands
// on with the step they just filled out behind them. Re-submit instead, from
// behind the submit button's spinner.
export default class extends Controller {
  static values = { retries: { type: Number, default: 2 }, delay: { type: Number, default: 500 } }

  connect () {
    this.retried = 0
    this.element.addEventListener('turbo:before-fetch-response', this.retryTransient)
    this.element.addEventListener('turbo:submit-end', this.holdSubmit)
  }

  disconnect () {
    this.element.removeEventListener('turbo:before-fetch-response', this.retryTransient)
    this.element.removeEventListener('turbo:submit-end', this.holdSubmit)
    clearTimeout(this.timer)
  }

  // Only what a second try could answer differently: a throttle and the 5xxs.
  // The steps re-render themselves 422 when what was entered is the problem.
  retryTransient = (event) => {
    const status = event.detail.fetchResponse?.response?.status
    if (!(status === 429 || (status >= 500 && status < 600))) return
    if (this.retried >= this.retriesValue) return

    event.preventDefault() // ours to handle now, so Turbo leaves the page alone
    this.retried += 1
    this.retrying = true
    this.timer = setTimeout(() => {
      this.retrying = false
      // No submitter, so a disabled button doesn't hold this back
      this.element.requestSubmit()
    }, this.delayValue * this.retried)
  }

  // Turbo re-enables the button it submitted from once the submission finishes, which
  // this one has - but the submit hasn't, so leave it disabled under the spinner it's
  // still showing. A second click during the wait would submit the step twice.
  holdSubmit = () => {
    if (!this.retrying) return

    this.element.querySelectorAll('button[type="submit"]').forEach((button) => { button.disabled = true })
  }
}
