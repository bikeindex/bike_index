import { Controller } from '@hotwired/stimulus'

/* global setTimeout, clearTimeout, document, Event */

// Connects to data-controller='register--retry'
//
// Every step submits through Turbo, so a throttled or restarting server is a response to
// take over rather than an error page the rider lands on with their filled-out step
// behind them. Retry behind the submit spinner; when a retry won't help, say so and give
// the button back - Turbo can't, since rack_attack answers text/plain, which it renders
// as nothing.
export default class extends Controller {
  static values = {
    retries: { type: Number, default: 2 },
    delay: { type: Number, default: 500 },
    // Past this a spinner is worse than saying so - throttles ask for tens of seconds
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

  // Only what a second try could answer differently: a throttle and the 5xxs - a step
  // re-renders itself 422 when what was entered is the problem
  retryTransient = (event) => {
    // It bubbles, so it carries what Turbo fetches for elements inside the form too -
    // the combobox's paginated options frame is nobody's submission
    if (event.target !== this.element) return

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

  // null when another try is pointless: the attempts are spent, or the wait asked for is
  // longer than we'll hold them for
  delayFor (response) {
    if (this.retried >= this.retriesValue) return null

    const retryAfter = Number(response?.headers?.get('retry-after')) * 1000
    if (!retryAfter) return this.delayValue * (this.retried + 1)

    return (retryAfter > this.maxDelayValue) ? null : retryAfter
  }

  giveUp () {
    this.retrying = false
    // The notice asks for another try, so that try gets a full budget of its own
    this.retried = 0
    // The notice lives on the page shell, which can be a screen above the button they
    // pressed - unscrolled, the failure looks like a spinner that stopped
    const notice = document.querySelector('[data-register-retry-notice]')
    notice?.removeAttribute('hidden')
    notice?.scrollIntoView({ behavior: 'smooth', block: 'center' })
    this.submitButtons.forEach((button) => button.dispatchEvent(new Event('spinner:reset')))
  }

  // Turbo re-enables the submitter once the submission finishes - but the submit hasn't,
  // and a second click during the wait would submit the step twice
  holdSubmit = () => {
    if (!this.retrying) return

    this.submitButtons.forEach((button) => { button.disabled = true })
  }

  get submitButtons () {
    return this.element.querySelectorAll('button[type="submit"]')
  }
}
