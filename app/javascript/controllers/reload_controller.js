import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='reload'
// Reloads the page every 5 seconds while connected, for a page waiting on background work
export default class extends Controller {
  connect () {
    this.timer = setTimeout(() => window.location.reload(), 5000)
  }

  disconnect () {
    clearTimeout(this.timer)
  }
}
