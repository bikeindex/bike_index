import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--format-message'
//
// Says what the pattern wants rather than "Please match the requested format". A blank
// or missing value keeps the browser's own message
export default class extends Controller {
  static values = { message: String }

  explain () {
    if (this.element.validity.patternMismatch) this.element.setCustomValidity(this.messageValue)
  }

  // A custom validity holds until it's cleared, so a corrected value would still be refused
  reset () { this.element.setCustomValidity('') }
}
