import { Controller } from '@hotwired/stimulus'

/* global setTimeout, clearTimeout, document, Event */

// Connects to data-controller='register--retry'
//
// Every step submits through Turbo, so a throttled or restarting server comes back as
// a response we can take over rather than an error page the rider lands on with the
// step they just filled out behind them. Re-submit from behind the submit button's
// spinner - and when a retry won't help, say so and give the button back. Turbo can't
// do that part for us: rack_attack answers text/plain, which it renders as nothing.
export default class extends Controller {
  static values = {
    retries: { type: Number, default: 2 },
    delay: { type: Number, default: 500 },
    // Past this, waiting it out behind a spinner is worse than saying so - a throttle
    // asking to be waited for counts in tens of seconds
    maxDelay: { type: Number, default: 3000 }
  }

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
    const response = event.detail.fetchResponse?.response
    const status = response?.status
    if (!(status === 429 || (status >= 500 && status < 600))) return

    event.preventDefault() // ours to handle now, so Turbo leaves the page alone
    const delay = this.delayFor(response)
    if (delay === null) return this.giveUp()

    this.retried += 1
    this.retrying = true
    this.timer = setTimeout(() => {
      this.retrying = false
      this.element.requestSubmit() // no submitter, so the held button doesn't hold this back
    }, delay)
  }

  // null when another try is pointless: the attempts are spent, or the response asks to
  // be waited for longer than we're willing to keep them waiting
  delayFor (response) {
    if (this.retried >= this.retriesValue) return null

    const retryAfter = Number(response?.headers?.get('retry-after')) * 1000
    if (!retryAfter) return this.delayValue * (this.retried + 1)

    return (retryAfter > this.maxDelayValue) ? null : retryAfter
  }

  giveUp () {
    this.retrying = false
    // The notice asks them to try again, so that try gets the attempts this one spent -
    // otherwise the second submission gives up the moment it fails, having retried nothing
    this.retried = 0
    // The notice is on the page shell, which wraps this form rather than sitting inside it -
    // so it's above a step whose submit button can be a screen or more below it. Scroll it to
    // them, or all the failure looks like is a spinner that stopped
    const notice = document.querySelector('[data-register-retry-notice]')
    notice?.removeAttribute('hidden')
    notice?.scrollIntoView({ behavior: 'smooth', block: 'center' })
    this.submitButtons.forEach((button) => button.dispatchEvent(new Event('spinner:reset')))
  }

  // Turbo re-enables the button it submitted from once the submission finishes, which this
  // one has - but the submit hasn't, so leave it disabled under the spinner it's still
  // showing. A second click during the wait would submit the step twice.
  holdSubmit = () => {
    if (!this.retrying) return

    this.submitButtons.forEach((button) => { button.disabled = true })
  }

  get submitButtons () {
    return this.element.querySelectorAll('button[type="submit"]')
  }
}
