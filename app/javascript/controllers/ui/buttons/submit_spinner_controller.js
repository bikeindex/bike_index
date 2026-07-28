import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller="ui--buttons--submit-spinner" (on a submit button - rendered
// by UI::Button spinner: true). Once the button's form actually submits
// (native validation has passed), disables the button and reveals its spinner.
export default class extends Controller {
  static targets = ['spinner']

  connect () {
    this.boundStart = this.start.bind(this)
    this.element.form?.addEventListener('submit', this.boundStart)
    // A cached back/forward restore would otherwise show the submitted state
    if (this.element.dataset.submitted) {
      delete this.element.dataset.submitted
      this.element.disabled = false
      this.spinnerTargets.forEach(spinner => collapse('hide', spinner, 0))
    }
  }

  disconnect () {
    this.element.form?.removeEventListener('submit', this.boundStart)
  }

  start () {
    this.element.dataset.submitted = 'true'
    this.element.disabled = true
    this.spinnerTargets.forEach(spinner => collapse('show', spinner, 0))
  }
}
