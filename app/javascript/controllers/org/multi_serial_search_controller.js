import { Controller } from '@hotwired/stimulus'
import TimeLocalizer from '@bikeindex/time-localizer'

/* global window */

// Connects to data-controller='org--multi-serial-search'
export default class extends Controller {
  static targets = ['form', 'textarea', 'button']

  connect () {
    this.formTarget.addEventListener('turbo:submit-start', this.showLoading.bind(this))
    this.formTarget.addEventListener('turbo:submit-end', this.resetButton.bind(this))

    if (!window.timeLocalizer) window.timeLocalizer = new TimeLocalizer()
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.handleFrameRender)
  }

  submit (event) {
    if (this.textareaTarget.value.trim() === '') {
      event.preventDefault()
    }
  }

  showLoading () {
    if (this.hasButtonTarget) this.buttonTarget.disabled = true
  }

  resetButton () {
    if (this.hasButtonTarget) this.buttonTarget.disabled = false
  }

  handleFrameRender = () => {
    if (window.timeLocalizer && typeof window.timeLocalizer.localize === 'function') {
      window.timeLocalizer.localize()
    }
  }
}
