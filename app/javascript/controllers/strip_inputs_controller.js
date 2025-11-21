import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='strip-inputs'
// Strips leading and trailing whitespace from all text inputs on form submit and blur
export default class extends Controller {
  static inputSelector = 'input[type="text"], input[type="email"], input[type="search"], input[type="url"], input[type="tel"], input:not([type]), textarea'

  // If alwaysPreventSubmit is true, THE FORM WILL NEVER SUBMIT
  // (the embed forms have JS that handles submit, to prevent double submissions)
  static values = { alwaysPreventSubmit: Boolean }

  connect () {
    // Strip all inputs when any input loses focus
    this.element.addEventListener('focusout', this.stripAllInputs.bind(this))
  }

  disconnect () {
    this.element.removeEventListener('focusout', this.stripAllInputs.bind(this))
  }

  handleFocusout (event) {
    if (event.target.matches(this.constructor.inputSelector)) {
      this.stripAllInputs()
    }
  }

  stripAllInputs () {
    const textInputs = this.element.querySelectorAll(this.constructor.inputSelector)
    textInputs.forEach(input => {
      input.value = input.value.trim()
    })
  }

  submit (event) {
    this.stripAllInputs()

    // Find first invalid field after stripping
    const firstInvalid = this.element.querySelector(':invalid')
    if (firstInvalid) {
      event.preventDefault()
      // Focus and report validity on the first invalid field
      firstInvalid.focus()
      firstInvalid.reportValidity()
    } else {
      // Prevent submit if configured, then dispatch event
      if (this.alwaysPreventSubmitValue) {
        event.preventDefault()
      }
      this.dispatch('valid', { detail: { form: this.element } })
    }
  }
}
