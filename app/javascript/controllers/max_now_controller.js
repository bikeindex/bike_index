import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="max-now"
// Caps a datetime-local field at the browser's current time. The server can't: it
// doesn't know which zone the field's wall-clock value is in
export default class extends Controller {
  connect () {
    this.update()
    // Kept current, so a form left open (or a laptop asleep) still takes "just now"
    this.interval = setInterval(this.update, 60000)
    this.element.addEventListener('focus', this.update)
  }

  disconnect () {
    clearInterval(this.interval)
    this.element.removeEventListener('focus', this.update)
  }

  // A record saved with a future time stays saveable without the date being touched
  update = () => {
    const latest = Math.max(Date.now(), Date.parse(this.element.dataset.initialtime) || 0)
    const offsetMilliseconds = new Date(latest).getTimezoneOffset() * 60000
    this.element.max = new Date(latest - offsetMilliseconds).toISOString().slice(0, 16)
  }
}
