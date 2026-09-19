import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='admin--per-page-select'
export default class extends Controller {
  navigate ({ target }) {
    const url = new URL(window.location)
    url.searchParams.set('per_page', target.value)
    window.location = url.toString()
  }
}
