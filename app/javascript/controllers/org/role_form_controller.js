import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--role-form'
export default class extends Controller {
  static targets = ['submit']

  check () {
    const radios = [...this.element.querySelectorAll('input[type=radio]')]
    this.submitTarget.disabled = radios.every((radio) => radio.checked === radio.defaultChecked)
  }
}
