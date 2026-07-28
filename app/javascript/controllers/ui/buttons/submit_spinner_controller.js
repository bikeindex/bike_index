import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="ui--buttons--submit-spinner" (on a submit button - rendered
// by UI::Button spinner: true). Once the button's form actually submits
// (native validation has passed), disables the button and reveals its spinner.
export default class extends Controller {
  static targets = ['spinner']

  connect () {
    // Cached, because a detached button's .form is null - disconnect couldn't find it to unsubscribe
    this.form = this.element.form
    this.form?.addEventListener('submit', this.start)
    // A cached back/forward restore would otherwise show the submitted state
    if (this.element.dataset.submitted) {
      delete this.element.dataset.submitted
      this.element.disabled = false
      this.spinnerTarget.classList.add('tw:hidden')
    }
  }

  disconnect () {
    this.form?.removeEventListener('submit', this.start)
    this.form = null
  }

  start = () => {
    this.element.dataset.submitted = 'true'
    this.element.disabled = true
    this.spinnerTarget.classList.remove('tw:hidden')
  }
}
