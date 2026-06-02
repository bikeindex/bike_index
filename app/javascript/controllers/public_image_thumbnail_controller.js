import { Controller } from '@hotwired/stimulus'

// Reloads a bike photo thumbnail whose resized version is still being generated
// by the background image processor, retrying until it appears.
// Connects to data-controller='public-image-thumbnail'
export default class extends Controller {
  static values = {
    src: String,
    maxAttempts: { type: Number, default: 15 },
    interval: { type: Number, default: 2000 }
  }

  connect () {
    this.attempts = 0
  }

  disconnect () {
    if (this.timer) clearTimeout(this.timer)
  }

  // The thumbnail 404s while its :small version is still processing. Hide the
  // broken image so the "processing" message shows, then retry shortly. The
  // query param busts the browser's cache of the 404.
  retry () {
    this.element.style.display = 'none'
    if (this.attempts >= this.maxAttemptsValue) return

    this.attempts += 1
    this.timer = setTimeout(() => {
      this.element.src = `${this.srcValue}?retry=${this.attempts}`
    }, this.intervalValue)
  }

  loaded () {
    this.element.style.display = ''
  }
}
