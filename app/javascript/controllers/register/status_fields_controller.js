import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global window */

// Connects to data-controller='register--status-fields'
//
// Fields only some registration statuses ask for - phone, address - gated the
// way bikes/new gates them. bikes/new knows the status before it renders; here
// it's picked in this form, so each field carries its own statuses and gets
// rechecked whenever the combobox changes.
export default class extends Controller {
  static targets = ['field']

  connect () {
    // form-persist restores a drafted status by assignment, firing no event
    this.boundRestore = () => this.applyStatuses(0)
    window.addEventListener('form-persist:restored', this.boundRestore)
  }

  disconnect () {
    window.removeEventListener('form-persist:restored', this.boundRestore)
  }

  update () {
    this.applyStatuses()
  }

  applyStatuses (duration) {
    const status = this.element.querySelector('input[name$="[status]"]')?.value
    this.fieldTargets.forEach((field) => {
      collapse(JSON.parse(field.dataset.statuses).includes(status) ? 'show' : 'hide', field, duration)
    })
  }
}
