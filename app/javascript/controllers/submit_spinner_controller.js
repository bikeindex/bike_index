import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller="submit-spinner" (on a form)
// Wire data-action="submit->submit-spinner#start". Once the form actually
// submits (native validation has passed), disables the form's submit buttons
// and reveals their spinners (UI::Button spinner: true).
export default class extends Controller {
  static targets = ['spinner']

  // A cached back/forward restore would otherwise show the submitted state
  connect () {
    this.submitButtons.forEach(button => { button.disabled = false })
    this.spinnerTargets.forEach(spinner => collapse('hide', spinner, 0))
  }

  start () {
    this.submitButtons.forEach(button => { button.disabled = true })
    this.spinnerTargets.forEach(spinner => collapse('show', spinner, 0))
  }

  get submitButtons () {
    return this.element.querySelectorAll('button[type=submit]')
  }
}
