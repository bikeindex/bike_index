import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='registrations--show--message-owner'
export default class extends Controller {
  static targets = ['organizationMessage', 'stolenNotification']

  select (event) {
    const theft = event.target.value === 'theft'
    collapse(theft ? 'hide' : 'show', this.organizationMessageTarget)
    collapse(theft ? 'show' : 'hide', this.stolenNotificationTarget)
  }
}
