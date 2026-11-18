import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='register--acknowledgment'
//
// Agreed to as a whole, so the submit button stays disabled until every checkbox
// in the form is checked.
export default class extends Controller {
  static targets = ['checkbox', 'submit']

  connect () {
    this.update()
  }

  update () {
    this.submitTarget.disabled = !this.checkboxTargets.every((checkbox) => checkbox.checked)
  }
}
