import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="autofocus"
// Focuses the field marked autofocus inside the element, or else the first one, so the
// form is ready to type into on load. Skips hidden, disabled and unrendered fields (a
// collapsed section).
const FIELDS = [
  'input:not([type=hidden]):not([type=submit]):not([type=button]):not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])'
].join(', ')

export default class extends Controller {
  connect () {
    // Lazily loaded, so connect can land after the rider picked a field of their own -
    // focusing then would take the caret off it
    if (this.element.contains(document.activeElement)) return

    const fields = [...this.element.querySelectorAll(FIELDS)].filter((el) => el.offsetParent !== null)
    const field = fields.find((el) => el.autofocus) || fields[0]
    field?.focus()
  }
}
