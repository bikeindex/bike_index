import { Controller } from '@hotwired/stimulus'
import TimeLocalizer from 'utils/time_localizer'

/* global window  */

// Connects to data-controller='search--form'
export default class extends Controller {
  static targets = ['form', 'button']
  static values = {
    spinnerId: { type: String, default: 'hiddenLoadingSpinner' },
    cleanUrlDefaults: { type: Object, default: {} }
  }

  get frameElement () {
    const turboFrameId = this.formTarget.getAttribute('data-turbo-frame')

    return (document.getElementById(turboFrameId))
  }

  initialize () {
    // every time the form submits, show the loading spinner
    this.formTarget.addEventListener('turbo:submit-start', this.showLoadingSpinnerAndDisableButton.bind(this))
    // re-enable the button when submission completes or fails
    this.formTarget.addEventListener('turbo:submit-end', this.resetButton.bind(this))
  }

  connect () {
    // Remove search_no_js hidden field
    const noJsElement = this.element.querySelector('#search_no_js')
    if (noJsElement) noJsElement.remove()

    // if the frame was loaded without results, submit the form
    if (this.frameElement?.querySelector('#loadedWithoutResults')) {
      // Use replace instead of advance for initial load to avoid adding to history
      this.formTarget.setAttribute('data-turbo-action', 'replace')
      this.formTarget.requestSubmit()
      this.formTarget.setAttribute('data-turbo-action', 'advance')
    }

    this.formTarget.addEventListener('turbo:submit-end', this.cleanUrlParams.bind(this))
    this.setupFormFieldListeners()

    // Add timeLocalizer and watch for turbo-frame renders
    if (!window.timeLocalizer) window.timeLocalizer = new TimeLocalizer()
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
  }

  disconnect () {
    // Clean up event listener when controller disconnects
    document.removeEventListener('turbo:frame-render', this.frameRenderHandler)
  }

  setupFormFieldListeners () {
    // Find all input, select, and textarea elements within the form
    const formFields = this.formTarget.querySelectorAll('input, select, textarea')

    // Add change event listeners to all form fields
    formFields.forEach(field => {
      // TODO: This doesn't catch changes to the query_items field
      field.addEventListener('change', this.resetButton.bind(this))
    })
  }

  showLoadingSpinnerAndDisableButton () {
    // Disable the submit button
    if (this.hasButtonTarget) { this.buttonTarget.disabled = true }

    if (!this.frameElement) return

    const spinnerWrapper = document.getElementById(this.spinnerIdValue)
    // IDK if this should clone instead of just use innerHTML - this seems much simpler
    this.frameElement.innerHTML = spinnerWrapper.innerHTML
  }

  resetButton () {
    if (this.hasButtonTarget) { this.buttonTarget.disabled = false }
  }

  cleanUrlParams () {
    const url = new URL(window.location)
    const params = url.searchParams
    let changed = false

    // Remove empty params
    for (const [key, value] of [...params.entries()]) {
      if (!value || value.trim() === '') {
        params.delete(key)
        changed = true
      }
    }

    // Remove params that match their default values
    const defaults = this.cleanUrlDefaultsValue
    for (const [key, defaultValue] of Object.entries(defaults)) {
      if (params.get(key) === String(defaultValue)) {
        params.delete(key)
        changed = true
      }
    }

    if (changed) {
      const newUrl = params.toString() ? `${url.pathname}?${params.toString()}` : url.pathname
      window.history.replaceState(window.history.state, '', newUrl)
    }
  }

  handleFrameRender = () => {
    // Run the time localization command on frame render
    if (window.timeLocalizer && typeof window.timeLocalizer.localize === 'function') {
      window.timeLocalizer.localize()
    }
  }
}
