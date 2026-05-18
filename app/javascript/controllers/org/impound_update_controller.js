import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--impound-update'
// Shows the form fields that apply to the selected impound-update kind
// (e.g. the location select for move_location). Used by both the impound
// records index multi-update form and the show-page update form.
export default class extends Controller {
  static targets = ['kindSelect', 'kindField']

  connect () {
    this.applyKind()
  }

  applyKind () {
    const kind = this.kindSelectTarget.value
    this.kindFieldTargets.forEach(field => {
      field.classList.toggle('tw:hidden', field.dataset.kind !== kind)
    })
  }
}
