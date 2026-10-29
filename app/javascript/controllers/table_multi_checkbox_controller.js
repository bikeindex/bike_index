import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="table-multi-checkbox"
export default class extends Controller {
  static targets = ['checkbox']

  connect () {
    this.element.addEventListener('keydown', this.ignoreFieldEnter)
  }

  disconnect () {
    this.element.removeEventListener('keydown', this.ignoreFieldEnter)
  }

  toggleAll (event) {
    event.preventDefault()
    // Disabled checkboxes can't be selected
    const anyUnchecked = this.checkboxTargets.some(cb => !cb.disabled && !cb.checked)
    this.checkboxTargets.forEach(cb => { if (!cb.disabled) cb.checked = anyUnchecked })
  }

  // Checks the row's checkbox, so editing a row's fields selects it
  selectRow (event) {
    if (event.target.type === 'checkbox') return
    const checkbox = event.target.closest('tr')?.querySelector('input[type=checkbox]')
    if (checkbox && !checkbox.disabled) checkbox.checked = true
  }

  // Editing a row checks it, so a submit button with data-discards-edits asks before acting on edited rows
  confirmDiscard (event) {
    if (!event.submitter?.dataset.discardsEdits) return
    const edited = this.checkboxTargets.filter(cb => cb.checked &&
      [...cb.closest('tr').querySelectorAll('input[type=text], textarea')].some(field => field.value !== field.defaultValue))
    if (edited.length === 0) return
    const message = `${edited.length} selected ${edited.length === 1 ? 'row has' : 'rows have'} edits, which this discards. Continue?`
    if (!window.confirm(message)) event.preventDefault()
  }

  // Enter in a checkbox, or a text field in a row, would submit the form through its first button, a bulk action
  ignoreFieldEnter = (event) => {
    const { type } = event.target
    if (event.key === 'Enter' && (type === 'checkbox' || (type === 'text' && event.target.closest('td')))) event.preventDefault()
  }
}
