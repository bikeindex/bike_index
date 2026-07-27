import { Controller } from '@hotwired/stimulus'
import { collapse, CollapseUtils } from 'utils/collapse_utils'

// Connects to data-controller='registrations--new--additional-colors'
//
// Reveals the secondary then tertiary color rows one at a time. Removing a row
// clears its combobox so the color isn't submitted, and brings the add button back.
export default class extends Controller {
  static targets = ['row', 'addButton']

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
