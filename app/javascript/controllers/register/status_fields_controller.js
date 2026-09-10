import { Controller } from '@hotwired/stimulus'
import { collapseField } from 'utils/collapse_utils'

/* global window */

// Connects to data-controller='register--status-fields'
//
// What a registration status asks for, rechecked whenever the combobox changes.
// bikes/new knows the status before it renders; here it's picked in this form, so each
// piece carries its own answer: a field its data-statuses, and anything whose copy varies
// a data-texts map of status -> what to say. For a field, having copy is what makes it
// asked for rather than offered.
export default class extends Controller {
  static targets = ['field', 'submitLabel']

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
      // register--organization sets the flag. A field it only adds to carries the answers
      // for when it's dropped; one that only it asks for carries none, so dropping that
      // leaves it no status to show on
      const off = Boolean(field.dataset.organizationOff)
      const statuses = off ? (field.dataset.organizationOffStatuses || '[]') : field.dataset.statuses
      const texts = off ? field.dataset.organizationOffTexts : field.dataset.texts
      collapseField(field, JSON.parse(statuses).includes(status), duration)
      if (texts) this.applyRequired(field, JSON.parse(texts)[status])
    })
    // Backspacing the combobox empty deselects it, so keep the label it had rather
    // than writing an undefined status's missing text into the button
    const submitText = this.hasSubmitLabelTarget && JSON.parse(this.submitLabelTarget.dataset.texts)[status]
    if (submitText) this.submitLabelTarget.textContent = submitText
  }

  // The phone a theft or a find gets contacted on: required, starred rather than badged
  // optional, and captioned with which of them is asking
  applyRequired (field, text) {
    field.querySelectorAll('input, select, textarea').forEach((el) => { el.required = Boolean(text) })
    field.querySelectorAll('[data-required-marker]').forEach((el) => { el.hidden = !text })
    field.querySelectorAll('[data-optional-marker]').forEach((el) => { el.hidden = Boolean(text) })
    const helper = field.querySelector('[data-required-helper]')
    if (helper) {
      helper.textContent = text || ''
      helper.hidden = !text
    }
  }
}
