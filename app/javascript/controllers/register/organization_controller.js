import { Controller } from '@hotwired/stimulus'
import { collapseField } from 'utils/collapse_utils'

/* global window */

// Connects to data-controller='register--organization'
//
// The organization assigned from who the registrant is, which step 2 offers to drop -
// what it asks for goes with it. The address is register--status-fields' to show or
// hide, since the status has a say in that one too, so this only leaves it the answer
// to read. The checkbox is only rendered for an automatic assignment, so without one
// there is nothing here to toggle.
export default class extends Controller {
  static targets = ['checkbox', 'field', 'label', 'statusField']

  connect () {
    // form-persist restores a drafted checkbox by assignment, firing no event
    this.boundRestore = () => this.apply(0)
    window.addEventListener('form-persist:restored', this.boundRestore)
    this.apply(0)
  }

  disconnect () {
    window.removeEventListener('form-persist:restored', this.boundRestore)
  }

  toggle () {
    this.apply()
  }

  apply (duration) {
    if (!this.hasCheckboxTarget) return

    const registering = this.checkboxTarget.checked
    this.fieldTargets.forEach((field) => collapseField(field, registering, duration))
    this.labelTargets.forEach((label) => {
      label.textContent = JSON.parse(label.dataset.texts)[registering ? 'on' : 'off']
    })
    this.statusFieldTargets.forEach((field) => {
      if (registering) delete field.dataset.organizationOff
      else field.dataset.organizationOff = 'true'
    })
    // Announced rather than applied: register--status-fields reads the flag, and which of
    // us runs first isn't ours to decide when we're both answering form-persist's restore
    this.dispatch('changed')
  }
}
