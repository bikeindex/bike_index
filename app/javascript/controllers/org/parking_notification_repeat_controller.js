import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--parking-notification-repeat'
// Labels the submit for resolving when the kind is mark_retrieved, and as rendered otherwise
export default class extends Controller {
  static targets = ['submit']
  static values = { resolveText: String }

  connect () {
    this.createText = this.submitTarget.value
  }

  updateSubmitText (event) {
    this.submitTarget.value = event.target.value === 'mark_retrieved' ? this.resolveTextValue : this.createText
  }
}
