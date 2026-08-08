import { Controller } from '@hotwired/stimulus'

/* global Intl, Date */

// Connects to data-controller='register--report-date'
//
// The date field is wall-clock time, so it only means something alongside the zone
// it was entered in - which the server can't know. Defaults an unanswered field to
// the browser's now, rather than rendering the app's zone into it.
export default class extends Controller {
  static targets = ['timezone', 'date']

  connect () {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (zone) this.timezoneTarget.value = zone
    if (!this.dateTarget.value) this.dateTarget.value = this.localNow()
  }

  localNow () {
    const now = new Date()
    now.setMinutes(now.getMinutes() - now.getTimezoneOffset())
    return now.toISOString().slice(0, 16)
  }
}
