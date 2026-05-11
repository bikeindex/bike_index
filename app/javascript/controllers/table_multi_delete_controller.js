import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="table-multi-delete"
export default class extends Controller {
  static targets = ['checkbox']

  toggleAll (event) {
    event.preventDefault()
    const anyUnchecked = this.checkboxTargets.some(cb => !cb.checked)
    this.checkboxTargets.forEach(cb => { cb.checked = anyUnchecked })
  }
}
