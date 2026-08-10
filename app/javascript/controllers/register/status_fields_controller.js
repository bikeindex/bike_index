import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

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
      const shown = JSON.parse(field.dataset.statuses).includes(status)
      collapse(shown ? 'show' : 'hide', field, duration)
      // Collapsing only hides - disable too, or a stolen registration still posts
      // the address (its country select always has a value) and a phone the
      // status no longer asks for
      field.querySelectorAll('input, select, textarea').forEach((el) => { el.disabled = !shown })
      if (field.dataset.texts) this.applyRequired(field, this.textFor(field, status))
    })
    if (this.hasSubmitLabelTarget) {
      this.submitLabelTarget.textContent = this.textFor(this.submitLabelTarget, status)
    }
  }

  textFor (element, status) {
    return JSON.parse(element.dataset.texts)[status]
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
