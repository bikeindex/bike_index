import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='update-cached-sortable-links'
export default class extends Controller {
  static values = {
    baseUrl: String
  }

  connect () {
    this.updateLinks()
  }

  updateLinks () {
    // Get base URL from value
    const baseUrl = new URL(this.baseUrlValue, window.location.origin)

    // Update sortable links to preserve current URL query params
    this.element.querySelectorAll('a.display-sortable-link').forEach(link => {
      // Get the link's URL and params
      const linkUrl = new URL(link.href, window.location.origin)

      // Clone base URL for this link
      const newUrl = new URL(baseUrl)

      // Merge query params from link into current URL params
      linkUrl.searchParams.forEach((value, key) => {
        newUrl.searchParams.set(key, value)
      })

      // Update the link href
      link.href = newUrl.pathname + newUrl.search
    })
  }
}
