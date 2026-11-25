import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--role-form'
// Keeps the submit button disabled until the checked role differs from the saved one
export default class extends Controller {
  static targets = ['submit']

  connect () {
    this.savedRole = this.checkedRole()
  }

  check () {
    this.submitTarget.disabled = this.checkedRole() === this.savedRole
  }

  checkedRole () {
    return this.element.querySelector('input[type=radio]:checked')?.value
  }
}
