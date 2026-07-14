import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='registrations--new--additional-colors'
//
// Reveals the secondary then tertiary color rows one at a time. Removing a row
// clears its select so the color isn't submitted, and brings the add button back.
export default class extends Controller {
  static targets = ['row', 'addButton']

  add () {
    const hiddenRows = this.rowTargets.filter(row => this.hidden(row))
    if (hiddenRows.length === 0) return

    collapse('show', hiddenRows[0])
    if (hiddenRows.length === 1) collapse('hide', this.addButtonTarget)
  }

  remove (event) {
    const row = event.target.closest('[data-registrations--new--additional-colors-target="row"]')
    row.querySelector('select').value = ''
    collapse('hide', row)
    if (this.hidden(this.addButtonTarget)) collapse('show', this.addButtonTarget)
  }

  hidden (element) {
    return element.classList.contains('tw:hidden') || element.classList.contains('tw:hidden!')
  }
}
