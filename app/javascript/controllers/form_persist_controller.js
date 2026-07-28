import { Controller } from '@hotwired/stimulus'

/* global localStorage, setTimeout, clearTimeout, Date, window, CustomEvent, CSS */

// Connects to data-controller="form-persist"
// Mirrors form fields to localStorage so a draft survives page reloads —
// text fields by value, checkboxes/radios by checked state, and
// hotwire_combobox pairs (hidden value + display text) together.
// Wire data-action="input->form-persist#save change->form-persist#save
// hw-combobox:selection->form-persist#save submit->form-persist#clear".
// The storage key defaults to pathname + the form's action (see derivedKey);
// set data-form-persist-key-value only when that isn't unique per form.
// Writes are debounced (DEBOUNCE_MS) and a restored draft is discarded once
// older than TTL_MS.
const DEBOUNCE_MS = 400
const TTL_MS = 604800000 // 1 week

export default class extends Controller {
  static values = { key: String }

  connect () {
    // Deferred so sibling controllers have connected before the restore and
    // its form-persist:restored window event, whatever the connect order.
    this.restoreTimer = setTimeout(() => this.restore(), 0)
    // Flush a pending debounced write before the page unloads, so quickly
    // typing then reloading doesn't drop the last keystrokes.
    this.boundFlush = this.flush.bind(this)
    window.addEventListener('pagehide', this.boundFlush)
  }

  disconnect () {
    clearTimeout(this.timer)
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

  clear () {
    clearTimeout(this.timer)
    localStorage.removeItem(this.storageKey)
  }

  // Stored values only fill fields the server rendered empty — a field the
  // server filled is at least as fresh as the draft. Checkboxes and selects
  // have no empty state to detect, so the draft wins for them.
  restore () {
    const stored = this.read()
    this.fields.forEach((field) => {
      const value = stored[field.name]
      if (value == null) return
      if (field.type === 'radio') {
        if (!this.radioGroupChecked(field.name)) field.checked = field.value === value
      } else if (field.type === 'checkbox') {
        field.checked = value === true
      } else if (!field.value || field.tagName === 'SELECT') {
        field.value = value
      }
    })
    this.comboboxes.forEach(({ hidden, display }) => {
      if (stored[hidden.name] == null) return
      // data-persist-default marks a value the server suggested rather than holds,
      // so unlike a real one it doesn't outrank the draft (UI::Forms::Combobox)
      if ((hidden.value || display.value) && hidden.dataset.persistDefault == null) return
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

  get fields () {
    return this.element.querySelectorAll(
      'textarea, select, input:not([type=hidden]):not([type=file]):not([type=submit]):not([type=button]):not(.hw-combobox__input)'
    )
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
