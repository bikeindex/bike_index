import { Controller } from '@hotwired/stimulus'
import { collapse, CollapseUtils } from 'utils/collapse_utils'

/* global window */

// Connects to data-controller='register--additional-colors'
//
// Reveals the secondary then tertiary color rows one at a time. Removing a row
// clears its combobox so the color isn't submitted, and brings the add button back.
export default class extends Controller {
  static targets = ['row', 'addButton']

  connect () {
    this.boundReveal = this.revealFilledRows.bind(this)
    window.addEventListener('form-persist:restored', this.boundReveal)
    this.revealFilledRows()
  }

  disconnect () {
    window.removeEventListener('form-persist:restored', this.boundReveal)
  }

  // form-persist restores drafted colors into collapsed rows - reveal them
  revealFilledRows () {
    const hiddenRows = this.rowTargets.filter(row => !CollapseUtils.isVisible(row))
    const filledRows = hiddenRows.filter(row => row.querySelector('input[data-hw-combobox-target="hiddenField"]')?.value)
    filledRows.forEach(row => collapse('show', row, 0))
    if (filledRows.length > 0 && filledRows.length === hiddenRows.length) {
      collapse('hide', this.addButtonTarget, 0)
    }
  }

  add () {
    const hiddenRows = this.rowTargets.filter(row => !CollapseUtils.isVisible(row))
    if (hiddenRows.length === 0) return

    collapse('show', hiddenRows[0])
    if (hiddenRows.length === 1) collapse('hide', this.addButtonTarget)
  }

  remove (event) {
    const row = this.rowTargets.find(target => target.contains(event.target))
    row.querySelectorAll('input').forEach(input => { input.value = '' })
    // Let the combobox-display overlay clear now that the value is gone
    row.querySelector('.hw-combobox__input')?.dispatchEvent(new Event('hw-combobox:selection', { bubbles: true }))
    collapse('hide', row)
    if (!CollapseUtils.isVisible(this.addButtonTarget)) collapse('show', this.addButtonTarget)
  }
}
