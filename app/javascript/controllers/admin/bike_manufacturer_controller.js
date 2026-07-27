import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='admin--bike-manufacturer'
//
// Shows the warning under the manufacturer combobox while the selected manufacturer
// is free text - an indexed manufacturer submits its id, the "Unknown manufacturer"
// option submits what was typed.
export default class extends Controller {
  static targets = ['warning']

  toggleWarning ({ detail: { value } }) {
    this.warningTarget.hidden = value === '' || /^\d+$/.test(value)
  }
}
