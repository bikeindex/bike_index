import { Controller } from '@hotwired/stimulus'

/* global localStorage */

// Connects to data-controller="form-persist"
// Mirrors named text fields to localStorage so a draft survives page reloads.
// Set data-form-persist-key-value to a stable per-form key, then wire
// data-action="input->form-persist#save submit->form-persist#clear".
export default class extends Controller {
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
    return this.element.querySelectorAll('textarea, input:not([type=hidden]):not([type=submit]):not([type=button])')
  }

  get storageKey () {
    return `form-persist:${this.keyValue}`
  }
}
