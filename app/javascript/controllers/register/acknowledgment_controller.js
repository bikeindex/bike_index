import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='register--acknowledgment'
//
// The safety rules are agreed to as a whole, so the submit button stays disabled
// until every checkbox on the page is checked.
export default class extends Controller {
  static targets = ['checkbox', 'submit']

  connect () {
    this.update()
  }

  update () {
    this.submitTarget.disabled = !this.checkboxTargets.every((checkbox) => checkbox.checked)
  }
}
