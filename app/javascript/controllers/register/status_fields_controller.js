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
  static targets = ['field', 'requiredField', 'submitLabel']

  connect () {
    // form-persist restores a drafted status by assignment, firing no event
    this.boundRestore = () => this.applyStatuses(0)
    window.addEventListener('form-persist:restored', this.boundRestore)
    this.applyStatuses(0)
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
      const shown = JSON.parse(field.dataset.statuses).includes(status)
      collapse(shown ? 'show' : 'hide', field, duration)
      // Collapsing only hides - disable too, or a stolen registration still posts
      // the address (its country select always has a value) and a phone the
      // status no longer asks for
      field.querySelectorAll('input, select, textarea').forEach((el) => { el.disabled = !shown })
    })
    this.requiredFieldTargets.forEach((field) => this.applyRequired(field, status))
    this.applySubmitLabel(status)
  }

  // Fields some statuses ask for rather than offer - the phone a theft or a find gets
  // contacted on. The copy for each status renders with the field, so which one applies
  // is a lookup rather than a rebuilt label
  applyRequired (field, status) {
    const text = JSON.parse(field.dataset.requiredTexts)[status]
    field.querySelectorAll('input, select, textarea').forEach((el) => { el.required = Boolean(text) })
    field.querySelectorAll('[data-required-marker]').forEach((el) => { el.hidden = !text })
    field.querySelectorAll('[data-optional-marker]').forEach((el) => { el.hidden = Boolean(text) })
    const helper = field.querySelector('[data-required-helper]')
    if (helper) {
      helper.textContent = text || ''
      helper.hidden = !text
    }
  }

  // A theft is reported after this form, so the button can't claim to finish the
  // registration - and which statuses do that is picked in this form too
  applySubmitLabel (status) {
    if (!this.hasSubmitLabelTarget) return

    const label = this.submitLabelTarget
    label.textContent = JSON.parse(label.dataset.statuses).includes(status)
      ? label.dataset.nextText
      : label.dataset.completeText
  }
}
