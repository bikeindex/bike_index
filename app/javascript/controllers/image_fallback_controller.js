import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='image-fallback'
// PublicImage versions (thumbnails) are generated in a background job, so a versioned
// src can 404 for a moment after upload until the worker finishes. Swap to the original
// (stored synchronously, always available) on load error so the image isn't broken until
// a page reload. Also handles an error that fired before this controller connected.
export default class extends Controller {
  static values = { url: String }

  connect () {
    if (this.element.complete && this.element.naturalWidth === 0) this.useOriginal()
  }

  useOriginal () {
    if (this.hasUrlValue && this.element.getAttribute('src') !== this.urlValue) {
      this.element.src = this.urlValue
    }
  }
}
