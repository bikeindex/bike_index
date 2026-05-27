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

    this.submitIfEmptyResults()
    this.setupFormFieldListeners()

    // Add timeLocalizer and watch for turbo-frame renders
    if (!window.timeLocalizer) window.timeLocalizer = new TimeLocalizer()
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
    // Re-check after Turbo navigations: on back/forward, connect() can fire
    // before the frame element is parsed, leaving #loadedWithoutResults in
    // place with no auto-submit.
    document.addEventListener('turbo:load', this.submitIfEmptyResults)
    // Same-document back/forward (a filter link advanced the URL without a
    // full page load) leaves the results frame's src stale. Re-point it at the
    // restored URL so the frame matches the address bar.
    window.addEventListener('popstate', this.reloadFrameFromUrl)
  }

  // if the frame was loaded without results, submit the form
  submitIfEmptyResults = () => {
    if (!this.frameElement?.querySelector('#loadedWithoutResults')) return
    // Use replace for the initial auto-submit so it doesn't add a duplicate history entry
    this.formTarget.setAttribute('data-turbo-action', 'replace')
    this.frameElement.addEventListener('turbo:frame-render', () => {
      this.formTarget.setAttribute('data-turbo-action', 'advance')
    }, { once: true })
    this.formTarget.requestSubmit()
  }

  // Only fires for same-document history navigation; cross-document back/forward
  // re-renders the page and submitIfEmptyResults handles it instead.
  reloadFrameFromUrl = () => {
    if (this.frameElement?.getAttribute('src')) {
      this.frameElement.setAttribute('src', window.location.href)
    }
  }

  disconnect () {
    // Clean up event listener when controller disconnects
    document.removeEventListener('turbo:frame-render', this.handleFrameRender)
    document.removeEventListener('turbo:load', this.submitIfEmptyResults)
    window.removeEventListener('popstate', this.reloadFrameFromUrl)
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

  // The form sits outside the results frame, so frame-nav period clicks advance
  // the URL but leave its hidden fields stale. Sync from the URL so the next
  // submit doesn't drop the period the user just chose.
  syncHiddenFieldsFromUrl () {
    const params = new URLSearchParams(window.location.search)
    this.formTarget.querySelectorAll('input[type="hidden"]').forEach(input => {
      // Skip array fields (eg query_items[]) - the combobox owns those, and
      // URLSearchParams.get would collapse them all to the first value
      if (!input.name || input.name.endsWith('[]') || !params.has(input.name)) return
      const newValue = params.get(input.name)
      if (input.value !== newValue) input.value = newValue
    })
  }
}
