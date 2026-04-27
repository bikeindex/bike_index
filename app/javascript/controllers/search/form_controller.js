import { Controller } from '@hotwired/stimulus'
import TimeLocalizer from '@bikeindex/time-localizer'

/* global window  */

// Connects to data-controller='search--form'
export default class extends Controller {
  static targets = ['form', 'button']
  static values = { spinnerId: { type: String, default: 'hiddenLoadingSpinner' } }

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
      // Use replace for the initial auto-submit so it doesn't add a duplicate history entry
      this.formTarget.setAttribute('data-turbo-action', 'replace')
      this.frameElement.addEventListener('turbo:frame-render', () => {
        this.formTarget.setAttribute('data-turbo-action', 'advance')
      }, { once: true })
      this.formTarget.requestSubmit()
    }

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

  handleFrameRender = () => {
    // Run the time localization command on frame render
    if (window.timeLocalizer && typeof window.timeLocalizer.localize === 'function') {
      window.timeLocalizer.localize()
    }
    this.syncHiddenFieldsFromUrl()
  }

  // Period buttons and the render-chart link live inside the results turbo-frame
  // and use data-turbo-action="advance" so the frame swaps in place and the URL
  // advances. The form (FormOrganized) sits outside the frame, so its hidden
  // fields (period, start_time, render_chart, etc.) keep the values they had at
  // initial render. Without this sync, the next form submit would carry stale
  // hidden values and silently drop the period the user just chose.
  //
  // Only update fields whose value actually differs from the URL — avoids
  // dispatching change events / dirtying inputs unnecessarily, and only touches
  // hidden fields so user-typed text inputs (search_email, serial, etc.) stay
  // intact even when the URL doesn't carry them yet.
  syncHiddenFieldsFromUrl () {
    const params = new URLSearchParams(window.location.search)
    this.formTarget.querySelectorAll('input[type="hidden"]').forEach(input => {
      if (!input.name || !params.has(input.name)) return
      const newValue = params.get(input.name)
      if (input.value !== newValue) input.value = newValue
    })
  }
}
