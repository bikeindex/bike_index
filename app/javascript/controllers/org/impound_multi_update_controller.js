import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='org--impound-multi-update'
// Drives the impound records index multi-update form: reveals the update panel
// and the checkbox column, shows the kind-specific fields, and enables only the
// checkboxes whose row supports the selected update kind.
export default class extends Controller {
  static targets = ['toggle', 'panel', 'kindSelect', 'kindField']

  open (event) {
    event.preventDefault()
    this.toggleTarget.classList.add('tw:hidden')
    collapse('show', this.panelTarget)
    this.cells.forEach(cell => cell.classList.remove('tw:hidden'))
    this.applyKind()
  }

  // Show the fields for the selected kind and enable only the rows that allow it
  applyKind () {
    const kind = this.kindSelectTarget.value

    this.kindFieldTargets.forEach(field => {
      field.classList.toggle('tw:hidden', field.dataset.kind !== kind)
    })

    this.cells.forEach(cell => {
      const checkbox = cell.querySelector('input[type=checkbox]')
      if (!checkbox) return

      const allowed = cell.classList.contains(`canupdate-${kind}`)
      checkbox.disabled = !allowed
      if (allowed) {
        cell.removeAttribute('title')
      } else {
        checkbox.checked = false
        cell.title = `This record can't be updated with '${this.kindLabel}'`
      }
    })
  }

  selectAll (event) {
    event.preventDefault()
    this.allChecked = !this.allChecked
    this.cells.forEach(cell => {
      const checkbox = cell.querySelector('input[type=checkbox]')
      if (checkbox && !checkbox.disabled) checkbox.checked = this.allChecked
    })
  }

  get cells () {
    return this.element.querySelectorAll('.multi-update-cell')
  }

  get kindLabel () {
    return this.kindSelectTarget.selectedOptions[0]?.text
  }
}
