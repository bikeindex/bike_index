import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='registrations--new--serial'
//
// The serial input is required unless the bike is marked as missing its serial.
export default class extends Controller {
  static targets = ['input', 'missing']

  connect () {
    this.toggle()
  }

  toggle () {
    const missing = this.missingTarget.checked
    this.inputTarget.disabled = missing
    this.inputTarget.required = !missing
    if (missing) this.inputTarget.value = ''
  }
}
