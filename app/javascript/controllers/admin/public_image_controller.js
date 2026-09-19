import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='admin--public-image'
export default class extends Controller {
  static values = { url: String }

  // manual, so a redirect (the unauthorized answer) reads as a failure rather than being followed
  async destroy () {
    const response = await fetch(this.urlValue, {
      method: 'DELETE',
      redirect: 'manual',
      headers: { Accept: 'application/json', 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content }
    })
    if (response.ok) this.element.remove()
  }
}
