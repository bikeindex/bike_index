import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='nested-list'
// Adds and removes repeated array inputs (e.g. a list of text fields). Add appends a clone of
// the template; remove drops the closest [data-nested-list-item]. Unlike nested-form there are
// no persisted records to flag for destruction — the array is rebuilt from the inputs on submit.
export default class extends Controller {
  static targets = ['list', 'template']

  add (event) {
    event.preventDefault()
    this.listTarget.insertAdjacentHTML('beforeend', this.templateTarget.innerHTML)
  }

  remove (event) {
    event.preventDefault()
    event.target.closest('[data-nested-list-item]')?.remove()
  }
}
