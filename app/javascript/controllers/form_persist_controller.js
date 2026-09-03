import { Controller } from '@hotwired/stimulus'

/* global localStorage, setTimeout, clearTimeout, Date, window, CustomEvent, Event, CSS */

// Connects to data-controller="form-persist"
// Mirrors form fields to localStorage so a draft survives page reloads —
// text fields by value, checkboxes/radios by checked state, and
// hotwire_combobox pairs (hidden value + display text) together.
// Wire data-action="input->form-persist#save change->form-persist#save
// hw-combobox:selection->form-persist#save submit->form-persist#clear".
// The storage key defaults to pathname + the form's action (see derivedKey);
// set data-form-persist-key-value only when that isn't unique per form.
// A restore is announced as form-persist:restored on window - a controller whose
// UI hangs off restored fields listens for it and reconciles in its own connect,
// since a lazily loaded module can arrive after the announcement.
// Writes are debounced (DEBOUNCE_MS) and a restored draft is discarded once
// older than TTL_MS.
const DEBOUNCE_MS = 400
const TTL_MS = 604800000 // 1 week

export default class extends Controller {
  static values = { key: String }

  connect () {
    // Deferred so siblings connecting alongside this one hear the restore. A later one
    // won't, whatever the delay -- it reconciles in its own connect.
    this.restoreTimer = setTimeout(() => this.restore(), 0)
    // Flush a pending debounced write before the page unloads, so quickly
    // typing then reloading doesn't drop the last keystrokes.
    this.boundFlush = this.flush.bind(this)
    window.addEventListener('pagehide', this.boundFlush)
  }

  // Flushed rather than dropped: a Turbo visit swaps the body without a pagehide, so
  // leaving mid-keystroke through a step's Back link would lose the last of what was
  // typed. clear() nulls the timer, so a submit still leaves nothing to write back
  disconnect () {
    this.flush()
    clearTimeout(this.restoreTimer)
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

  // timer is nulled as well as cancelled: a pending write left behind would have
  // pagehide's flush put the draft straight back, and submitting mid-keystroke is
  // exactly when there's one pending
  clear () {
    clearTimeout(this.timer)
    this.timer = null
    localStorage.removeItem(this.storageKey)
  }

  // Stored values only fill fields the server rendered empty — a field the
  // server filled is at least as fresh as the draft. Checkboxes, selects and
  // comboboxes have no empty state to detect (they render with a default
  // selection), so the draft wins for them.
  restore () {
    const stored = this.read()
    this.fields.forEach((field) => {
      const value = stored[field.name]
      if (value == null) return
      if (field.type === 'radio') {
        if (!this.radioGroupChecked(field.name)) field.checked = field.value === value
      } else if (field.type === 'checkbox') {
        field.checked = value === true
      } else if (field.tagName === 'SELECT') {
        field.value = value
        // A select drives sibling fields (org--impound-update, address-group),
        // and assigning the value fires nothing - so say what a user pick says
        field.dispatchEvent(new Event('change', { bubbles: true }))
      } else if (!field.value) {
        field.value = value
      }
    })
    this.comboboxes.forEach(({ hidden, display }) => {
      if (stored[hidden.name] == null) return
      hidden.value = stored[hidden.name]
      display.value = stored[`${hidden.name}::display`] || stored[hidden.name]
    })
    // Controllers whose UI hangs off restored fields (collapsed rows, checkbox
    // driven sections) reconcile on this event.
    window.dispatchEvent(new CustomEvent('form-persist:restored'))
  }

  write () {
    clearTimeout(this.timer)
    this.timer = null
    const data = {}
    this.fields.forEach((field) => {
      if (field.type === 'radio') {
        if (field.checked) data[field.name] = field.value
      } else if (field.type === 'checkbox') {
        data[field.name] = field.checked
      } else {
        data[field.name] = field.value
      }
    })
    this.comboboxes.forEach(({ hidden, display }) => {
      data[hidden.name] = hidden.value
      data[`${hidden.name}::display`] = display.value
    })
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

  radioGroupChecked (name) {
    return this.element.querySelector(`input[type=radio][name="${CSS.escape(name)}"]:checked`)
  }

  // Nameless fields would all share one key — hotwire_combobox renders two of
  // them per combobox (the display input and its small-viewport twin).
  get fields () {
    return [...this.element.querySelectorAll(
      'textarea, select, input:not([type=hidden]):not([type=file]):not([type=submit]):not([type=button])'
    )].filter((field) => field.name)
  }

  // hotwire_combobox splits each field into a nameless display input and a
  // hidden field carrying the real name/value — persist them as a pair.
  get comboboxes () {
    return [...this.element.querySelectorAll('fieldset.hw-combobox')].map((fieldset) => ({
      hidden: fieldset.querySelector('input[data-hw-combobox-target="hiddenField"]'),
      display: fieldset.querySelector('.hw-combobox__input')
    })).filter(({ hidden, display }) => hidden?.name && display)
  }

  get storageKey () {
    return `form-persist:${this.keyValue || this.derivedKey}`
  }

  // Fallback when no key-value is set: the form's action is resource-specific and
  // stable across reloads; pathname disambiguates forms that share an action.
  get derivedKey () {
    const action = this.element.getAttribute('action') || this.element.id || ''
    return `${window.location.pathname}${action}`
  }
}
