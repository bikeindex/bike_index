import { Controller } from '@hotwired/stimulus'

// Submits the surrounding form when a wired event fires (e.g. a combobox selection).
export default class extends Controller {
  connect () {
    this.element.addEventListener('formdata', this.#preserveQueryState)
  }

  disconnect () {
    this.element.removeEventListener('formdata', this.#preserveQueryState)
  }

  submit () {
    // A multiselect combobox's hw-combobox:selection event fires before it writes the
    // newly picked value into its hidden field, so submitting on the same tick would
    // send the value from before this pick — defer to let that write land first.
    setTimeout(() => this.element.requestSubmit(), 0)
  }

  // A GET submit rebuilds the query string from form fields alone, dropping URL state
  // the form doesn't own (e.g. a disclosure's ?json=open). Listening on formdata
  // carries it across every submit, not just the ones routed through #submit.
  #preserveQueryState = ({ formData }) => {
    new URLSearchParams(window.location.search).forEach((value, name) => {
      if (!formData.has(name)) formData.append(name, value)
    })
  }
}
