import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='reload'
// Reloads while something runs - an export (the reload is also what sends an Avery export on to
// its file) or the duplicate review queues
export default class extends Controller {
  connect () {
    this.timer = setTimeout(() => window.location.reload(), 5000)
  }

  disconnect () {
    clearTimeout(this.timer)
  }
}
