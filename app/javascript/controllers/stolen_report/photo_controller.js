import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='stolen-report--photo'
// Stores the picked photo on the bike right away, and fills the tile with what the endpoint answers -
// the report's own submission carries nothing for it
export default class extends Controller {
  static targets = ['status']
  static values = { url: String, uploading: String, failed: String }

  upload ({ target }) {
    const file = target.files[0]
    if (!file) return

    const body = new FormData()
    body.append('photo', file)
    this.statusTarget.textContent = this.uploadingValue

    window.fetch(this.urlValue, {
      method: 'POST',
      body,
      headers: { 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content, Accept: 'application/json' }
    })
      .then((response) => response.json())
      .then((json) => {
        if (!json.html) throw new Error(json.error)

        this.element.innerHTML = json.html
        this.element.dataset.photoAdded = 'true'
        this.dispatch('added', { detail: { kind: this.element.dataset.photoKind } })
      })
      .catch((error) => {
        target.value = ''
        this.statusTarget.textContent = error.message || this.failedValue
      })
  }
}
