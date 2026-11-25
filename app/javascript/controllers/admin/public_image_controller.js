import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='admin--public-image'
export default class extends Controller {
  static values = { url: String }

  async destroy () {
    const response = await fetch(this.urlValue, {
      method: 'DELETE',
      headers: { Accept: 'application/json', 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content }
    })
    if (response.ok) this.element.remove()
  }
}
