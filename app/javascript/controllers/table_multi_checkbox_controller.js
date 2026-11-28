import { Controller } from '@hotwired/stimulus'
import { collapseField } from 'utils/collapse_utils'
import { urlParam, setUrlParam } from 'utils/url_param'

// Connects to data-controller="table-multi-checkbox"
// whenChecked targets show only while a row is checked. Dispatches table-multi-checkbox:change as the selection does.
// The URL's checked param holds the checked values, or "all", so a reload keeps them
export default class extends Controller {
  static targets = ['checkbox', 'whenChecked']

  connect () {
    this.element.addEventListener('keydown', this.ignoreFieldEnter)
    this.element.addEventListener('click', this.selectRange)
    this.restoreChecked()
    this.syncWhenChecked(0)
  }

  disconnect () {
    this.element.removeEventListener('keydown', this.ignoreFieldEnter)
    this.element.removeEventListener('click', this.selectRange)
  }

  // Shift-clicking a checkbox gives every one from the last clicked to it the state it took
  selectRange = (event) => {
    const checkboxes = this.checkboxTargets
    const clicked = checkboxes.indexOf(event.target)
    if (clicked === -1) return

    const last = checkboxes.indexOf(this.lastClicked)
    if (event.shiftKey && last !== -1) {
      checkboxes.slice(Math.min(last, clicked), Math.max(last, clicked) + 1)
        .forEach(checkbox => { if (!checkbox.disabled) checkbox.checked = event.target.checked })
    }
    this.lastClicked = event.target
    this.syncWhenChecked()
  }

  toggleAll (event) {
    event.preventDefault()
    const anyUnchecked = this.enabledCheckboxes.some(cb => !cb.checked)
    this.enabledCheckboxes.forEach(cb => { cb.checked = anyUnchecked })
    this.syncWhenChecked()
  }

  // Checks the row's checkbox, so editing a row's fields selects it
  selectRow (event) {
    if (event.target.type === 'checkbox') return
    const checkbox = event.target.closest('tr')?.querySelector('input[type=checkbox]')
    if (checkbox && !checkbox.disabled) checkbox.checked = true
    this.syncWhenChecked()
  }

  syncWhenChecked (duration) {
    const checked = this.checkboxTargets.some(cb => cb.checked)
    this.whenCheckedTargets.forEach(field => collapseField(field, checked, duration, 'horizontal'))
    this.dispatch('change', { detail: { checked } })
    this.writeChecked()
  }

  restoreChecked () {
    const param = urlParam('checked')
    if (!param) return

    const values = param.split(',')
    this.enabledCheckboxes.forEach(cb => { cb.checked = param === 'all' || values.includes(cb.value) })
  }

  writeChecked () {
    const checked = this.checkboxTargets.filter(cb => cb.checked)
    const all = checked.length > 0 && this.enabledCheckboxes.every(cb => cb.checked)
    const value = all ? 'all' : (checked.map(cb => cb.value).join(',') || null)
    // Typing in a row's field selects it on every keystroke, and Safari throws past 100 replaceStates in 10 seconds
    if (value !== urlParam('checked')) setUrlParam('checked', value)
  }

  get enabledCheckboxes () {
    return this.checkboxTargets.filter(cb => !cb.disabled)
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
