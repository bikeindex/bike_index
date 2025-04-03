import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='search--form--component'
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
      this.formTarget.requestSubmit()
    }

    this.setupFormFieldListeners()
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
}
