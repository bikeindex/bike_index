import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="autofocus"
// Focuses the first field inside the element, so the form is ready to type into
// on load. Skips hidden, disabled and unrendered fields (a collapsed section).
const FIELDS = [
  'input:not([type=hidden]):not([type=submit]):not([type=button]):not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])'
].join(', ')

export default class extends Controller {
  connect () {
    const field = [...this.element.querySelectorAll(FIELDS)].find((el) => el.offsetParent !== null)
    field?.focus()
  }
}
