import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='registrations--show--message-owner'
// Swaps the organization message form for the stolen notification form when the toggle says stolen
export default class extends Controller {
  static targets = ['organizationMessage', 'stolenNotification']

  select (event) {
    const stolen = event.target.value === 'stolen'
    collapse(stolen ? 'hide' : 'show', this.organizationMessageTarget)
    collapse(stolen ? 'show' : 'hide', this.stolenNotificationTarget)
  }
}
