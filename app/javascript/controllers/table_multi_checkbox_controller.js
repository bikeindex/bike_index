import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="table-multi-checkbox"
export default class extends Controller {
  static targets = ['checkbox']

  toggleAll (event) {
    event.preventDefault()
    // Skip disabled checkboxes (e.g. impound rows that don't allow the selected kind)
    const anyUnchecked = this.checkboxTargets.some(cb => !cb.disabled && !cb.checked)
    this.checkboxTargets.forEach(cb => { if (!cb.disabled) cb.checked = anyUnchecked })
  }
}
