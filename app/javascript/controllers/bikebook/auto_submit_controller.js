import { Controller } from '@hotwired/stimulus'

// Submits the surrounding form when a wired event fires (e.g. a combobox selection).
export default class extends Controller {
  // A multiselect combobox's hw-combobox:selection event fires before it writes the
  // newly picked value into its hidden field, so submitting on the same tick would
  // send the value from before this pick — defer to let that write land first.
  submit () {
    setTimeout(() => this.element.requestSubmit(), 0)
  }
}
