import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='stolen-report--photo'
// Stores the picked photo on the bike right away, and fills the tile with what the endpoint answers -
// the report's own submission carries nothing for it. Removing it deletes it the same way
export default class extends Controller {
  static targets = ['status', 'empty']
  static values = { url: String, uploading: String, failed: String }

  upload ({ target }) {
    const file = target.files[0]
    if (!file) return

    const body = new FormData()
    body.append('photo', file)
    this.statusTarget.textContent = this.uploadingValue

    this.request(this.urlValue, { method: 'POST', body })
      .then((response) => response.json())
      .then((json) => {
        if (!json.html) throw new Error(json.error)

        this.fill(json.html, 'true')
        this.showInHeader(json.image_url)
        this.dispatch('added')
      })
      .catch((error) => {
        target.value = ''
        this.statusTarget.textContent = error.message || this.failedValue
      })
  }

  remove ({ params: { removeUrl } }) {
    this.request(removeUrl, { method: 'DELETE' })
      .then((response) => {
        if (!response.ok) throw new Error(response.statusText)

        this.fill(this.emptyTarget.innerHTML, 'false')
        this.dispatch('removed')
      })
      .catch(() => {})
  }

  // The template keeps the empty tile, so it stays put while the tile changes around it
  fill (html, added) {
    [...this.element.children].filter((child) => child !== this.emptyTarget).forEach((child) => child.remove())
    this.element.insertAdjacentHTML('beforeend', html)
    this.element.dataset.photoAdded = added
  }

  // The page's header shows the bike's first photo, which this may now be
  showInHeader (url) {
    const thumbnail = document.querySelector('[data-stolen-report-thumbnail]')
    if (!url || !thumbnail || thumbnail.querySelector('img')) return

    const image = document.createElement('img')
    image.src = url
    image.alt = ''
    image.className = 'tw:size-full tw:object-cover'
    thumbnail.replaceChildren(image)
  }

  request (url, options) {
    return window.fetch(url, {
      ...options,
      headers: { 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content, Accept: 'application/json' }
    })
  }
}
