import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--parking-notification-repeat'
export default class extends Controller {
  static targets = ['submit']

  updateSubmitText (event) {
    this.submitTarget.value = event.target.value === 'mark_retrieved' ? 'Resolve notification' : 'Create notification'
  }
}
