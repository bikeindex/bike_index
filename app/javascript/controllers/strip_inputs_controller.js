import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='strip-inputs'
// Strips leading and trailing whitespace from all text inputs on form submit
export default class extends Controller {
  submit (event) {
    // Find all text-based inputs in the form
    const textInputs = this.element.querySelectorAll(
      'input[type="text"], input[type="email"], input[type="search"], input[type="url"], input[type="tel"], input:not([type]), textarea'
    )

    // Strip whitespace from each input
    textInputs.forEach(input => {
      if (input.value) {
        input.value = input.value.trim()
      }
    })
    console.log('OOOO')
    // Let the form submit normally
  }
}
