import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='registrations--show--parking-notification-show'
// The panel around the form: the accordion tells it which trigger opened it, so
// it retitles for impound and passes the mode on to the form controller.
export default class extends Controller {
  static targets = ['heading']

  static values = {
    notificationHeading: String,
    impoundHeading: String
  }

  // Fired when the accordion reveals this panel
  applyMode (event) {
    const impound = event.detail?.name === 'impound'
    if (this.hasHeadingTarget) {
      this.headingTarget.textContent = impound ? this.impoundHeadingValue : this.notificationHeadingValue
    }
    // The form is a descendant, so a bubbling event never reaches it — go via window
    this.dispatch('mode', { detail: { impound }, target: window })
  }
}
