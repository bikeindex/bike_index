import { Controller } from '@hotwired/stimulus'

/* global localStorage */

// Connects to data-controller="form-persist"
// Mirrors named text fields to localStorage so a draft survives page reloads.
// Set data-form-persist-key-value to a stable per-form key, then wire
// data-action="input->form-persist#save submit->form-persist#clear". Mark
// specific fields with data-form-persist-target="field" to persist only those;
// otherwise every named text field in the form is persisted.
export default class extends Controller {
  static targets = ['field']
  static values = { key: String }

  connect () {
    const stored = this.read()
    this.fields.forEach((field) => {
      if (!field.value && stored[field.name] != null) field.value = stored[field.name]
    })
  }

  save () {
    const data = {}
    this.fields.forEach((field) => { data[field.name] = field.value })
    localStorage.setItem(this.storageKey, JSON.stringify(data))
  }

  clear () {
    localStorage.removeItem(this.storageKey)
  }

  read () {
    try {
      return JSON.parse(localStorage.getItem(this.storageKey)) || {}
    } catch {
      return {}
    }
  }

  get fields () {
    if (this.hasFieldTarget) return this.fieldTargets

    return this.element.querySelectorAll('textarea, input:not([type=hidden]):not([type=submit]):not([type=button])')
  }

  get storageKey () {
    return `form-persist:${this.keyValue}`
  }
}
