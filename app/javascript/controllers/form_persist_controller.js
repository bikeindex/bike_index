import { Controller } from '@hotwired/stimulus'

/* global localStorage, setTimeout, clearTimeout, Date, window */

// Connects to data-controller="form-persist"
// Mirrors named text fields to localStorage so a draft survives page reloads.
// Set data-form-persist-key-value to a stable per-form key, then wire
// data-action="input->form-persist#save submit->form-persist#clear".
// Writes are debounced (DEBOUNCE_MS) and a restored draft is discarded once
// older than TTL_MS.
const DEBOUNCE_MS = 400
const TTL_MS = 604800000 // 1 week

export default class extends Controller {
  static values = { key: String }

  connect () {
    const stored = this.read()
    this.fields.forEach((field) => {
      if (!field.value && stored[field.name] != null) field.value = stored[field.name]
    })
    // Flush a pending debounced write before the page unloads, so quickly
    // typing then reloading doesn't drop the last keystrokes.
    this.boundFlush = this.flush.bind(this)
    window.addEventListener('pagehide', this.boundFlush)
  }

  disconnect () {
    clearTimeout(this.timer)
    window.removeEventListener('pagehide', this.boundFlush)
  }

  // Debounced so a burst of keystrokes writes once, not per character.
  save () {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.write(), DEBOUNCE_MS)
  }

  flush () {
    if (this.timer) this.write()
  }

  clear () {
    clearTimeout(this.timer)
    localStorage.removeItem(this.storageKey)
  }

  write () {
    clearTimeout(this.timer)
    this.timer = null
    const data = {}
    this.fields.forEach((field) => { data[field.name] = field.value })
    localStorage.setItem(this.storageKey, JSON.stringify({ savedAt: Date.now(), data }))
  }

  read () {
    try {
      const { savedAt, data } = JSON.parse(localStorage.getItem(this.storageKey)) || {}
      if (savedAt == null || Date.now() - savedAt > TTL_MS) {
        this.clear()
        return {}
      }
      return data || {}
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
