import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='image-fallback', on an img or a wrapper around one
// PublicImage versions (thumbnails) are generated in a background job, so a versioned
// src can 404 for a moment after upload until the worker finishes. Swap to the original
// (stored synchronously, always available) on load error so the image isn't broken until
// a page reload. Also handles an error that fired before this controller connected.
// Without an original to swap to, it marks itself data-broken, for a placeholder to show.
export default class extends Controller {
  static values = { url: String }

  connect () {
    if (this.image.complete && this.image.naturalWidth === 0) this.fallBack()
  }

  fallBack () {
    if (this.hasUrlValue && this.image.getAttribute('src') !== this.urlValue) {
      this.image.src = this.urlValue
    } else {
      this.element.dataset.broken = ''
    }
  }

  get image () {
    return this.element.querySelector('img') ?? this.element
  }
}
