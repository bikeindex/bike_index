import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="table-multi-checkbox"
export default class extends Controller {
  static targets = ['checkbox']

  toggleAll (event) {
    event.preventDefault()
    // Disabled checkboxes can't be selected
    const anyUnchecked = this.checkboxTargets.some(cb => !cb.disabled && !cb.checked)
    this.checkboxTargets.forEach(cb => { if (!cb.disabled) cb.checked = anyUnchecked })
  }

  // Enter in a checkbox would submit the form through its first button, a bulk action
  ignoreCheckboxEnter (event) {
    if (event.target.type === 'checkbox') event.preventDefault()
  }
}
