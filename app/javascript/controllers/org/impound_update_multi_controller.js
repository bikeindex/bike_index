import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='org--impound-update-multi'
// The impound records index multi-update extras: reveals the update panel and
// the checkbox column, enables only the checkboxes whose row supports the
// selected update kind, and blocks submitting with nothing checked. The
// kind-specific fields are handled by the separate org--impound-update controller.
export default class extends Controller {
  static targets = ['toggle', 'panel', 'kindSelect', 'error']

  connect () {
    // The panel may be rendered already-open (multi_update=true) — in that
    // case sync the checkbox enabled state, since open() never runs.
    if (!this.panelTarget.classList.contains('tw:hidden')) {
      this.refreshChecks()
    }
  }

  open () {
    collapse('hide', this.toggleTarget)
    collapse('show', this.panelTarget)
    this.cells.forEach(cell => cell.classList.remove('tw:hidden'))
    this.refreshChecks()
    // Revealing the column changes which cell is last-visible — let the
    // ui--table controller re-apply edge rounding/borders.
    window.dispatchEvent(new Event('ui-table:refresh'))
    // Reflect the opened state in the URL without adding a history entry
    const url = new URL(window.location)
    url.searchParams.set('multi_update', 'true')
    window.history.replaceState(window.history.state, '', url)
  }

  // Block submitting the form with no rows checked, showing the error alert
  validate (event) {
    if (this.anyChecked) {
      collapse('hide', this.errorTarget)
    } else {
      collapse('show', this.errorTarget)
      event.preventDefault()
      // Stop the event reaching rails-ujs, which would otherwise disable the
      // data-disable-with submit button and leave it stuck (the form never
      // navigates away to get a fresh one).
      event.stopPropagation()
    }
  }

  // Once a row is checked, the "select a record" error no longer applies
  hideErrorIfChecked () {
    if (this.anyChecked) collapse('hide', this.errorTarget)
  }

  get anyChecked () {
    return [...this.cells].some(cell =>
      cell.querySelector('input[type=checkbox]')?.checked
    )
  }

  // Enable only the checkboxes whose row supports the selected kind
  refreshChecks () {
    const kind = this.kindSelectTarget.value
    this.cells.forEach(cell => {
      const checkbox = cell.querySelector('input[type=checkbox]')
      if (!checkbox) return

      const allowed = checkbox.dataset.updateKinds.split(' ').includes(kind)
      checkbox.disabled = !allowed
      if (allowed) {
        cell.removeAttribute('title')
      } else {
        checkbox.checked = false
        cell.title = `This record can't be updated with '${this.kindLabel}'`
      }
    })
  }

  get cells () {
    return this.element.querySelectorAll('.multi-update-cell')
  }

  get kindLabel () {
    return this.kindSelectTarget.selectedOptions[0]?.text
  }
}
