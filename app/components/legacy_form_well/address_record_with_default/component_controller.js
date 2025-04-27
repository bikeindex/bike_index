import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='legacy-form-well--address-record-with-default--component'
export default class extends Controller {
  static targets = ['useAccountCheckbox', 'staticFields', 'nonStaticFields']

  connect () {
    this.toggleUseAccount()
  }

  toggleUseAccount() {
    if (this.useAccountCheckboxTarget.checked) {
      this.staticFieldsTargets.forEach(targ => {
        collapse('show', targ)
      })
      this.nonStaticFieldsTargets.forEach(targ => {
        collapse('hide', targ)
      })
    } else {
      this.staticFieldsTargets.forEach(targ => {
        collapse('hide', targ)
      })
      this.nonStaticFieldsTargets.forEach(targ => {
        collapse('show', targ)
      })
    }
  }
}
