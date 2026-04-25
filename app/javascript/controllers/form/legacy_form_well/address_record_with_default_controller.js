import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='form--legacy-form-well--address-record-with-default'
export default class extends Controller {
  static targets = ['useAccountCheckbox', 'staticFields', 'nonStaticFields']

  connect () {
    if (this.hasUseAccountCheckboxTarget) {
      this.toggleUseAccount()
    }
  }

  toggleUseAccount () {
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
