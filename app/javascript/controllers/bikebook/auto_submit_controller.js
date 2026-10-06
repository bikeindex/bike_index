import { Controller } from '@hotwired/stimulus'

// Submits the surrounding form when a wired event fires, such as a combobox selection
export default class extends Controller {
  // A multiselect fires hw-combobox:selection before it writes the pick into its hidden field
  submit () {
    setTimeout(() => this.element.requestSubmit(), 0)
  }
}
