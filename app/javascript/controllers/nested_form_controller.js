import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='nested-form'
// Adds and removes nested fields_for records. The template target holds blank fields whose
// child_index placeholder is NEW_RECORD, replaced with a unique value on each insert. Removing
// a persisted record flips its hidden _destroy input; a not-yet-saved record is just dropped.
export default class extends Controller {
  static targets = ['list', 'template']

  add (event) {
    event.preventDefault()
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime().toString())
    this.listTarget.insertAdjacentHTML('beforeend', html)
  }

  remove (event) {
    event.preventDefault()
    const wrapper = event.target.closest('.nested-page')
    if (!wrapper) return

    const destroyInput = wrapper.querySelector('input[name*="_destroy"]')
    if (destroyInput) {
      destroyInput.value = '1'
      wrapper.style.display = 'none'
    } else {
      wrapper.remove()
    }
  }
}
