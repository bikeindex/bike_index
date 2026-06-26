import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='nested-form'
// Adds and removes repeated fields — both fields_for records (e.g. pages) and bare array inputs
// (e.g. bullet points), and nests (a bullet list lives inside a page). add() clones the template,
// replacing the NEW_RECORD child_index placeholder with a unique value (a no-op when absent).
// remove() flips a persisted record's hidden _destroy input and hides the item; an item with no
// _destroy input (e.g. an array entry) is just dropped.
export default class extends Controller {
  static targets = ['list', 'template']

  add (event) {
    event.preventDefault()
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime().toString())
    this.listTarget.insertAdjacentHTML('beforeend', html)
  }

  remove (event) {
    event.preventDefault()
    const item = event.target.closest('[data-nested-form-item]')
    if (!item) return

    const destroyInput = item.querySelector('input[name*="_destroy"]')
    if (destroyInput) {
      destroyInput.value = '1'
      item.style.display = 'none'
    } else {
      item.remove()
    }
  }
}
