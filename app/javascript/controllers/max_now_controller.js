import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="max-now"
// Caps a datetime-local field at the browser's current time. The server can't: it
// doesn't know which zone the field's wall-clock value is in
export default class extends Controller {
  connect () {
    const offsetMilliseconds = new Date().getTimezoneOffset() * 60000
    this.element.max = new Date(Date.now() - offsetMilliseconds).toISOString().slice(0, 16)
  }
}
