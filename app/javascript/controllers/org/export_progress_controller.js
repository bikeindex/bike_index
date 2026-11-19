import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--export-progress'
// Reloads while the export runs. The reload is also what sends an Avery export on to its file
export default class extends Controller {
  connect () {
    this.timer = setTimeout(() => window.location.reload(), 5000)
  }

  disconnect () {
    clearTimeout(this.timer)
  }
}
