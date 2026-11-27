import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='admin--bug-report-email-banned'
// Shows the alert while a checked row's sender is email banned
export default class extends Controller {
  static targets = ['alert']

  connect () {
    this.sync()
  }

  sync () {
    const banned = !!this.element.closest('form')?.querySelector('input[data-email-banned]:checked')
    collapse(banned ? 'show' : 'hide', this.alertTarget)
  }
}
