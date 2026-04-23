import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='period-select'
// Merges the current URL's query params when navigating via a period link so
// filters like search_email persist across period changes.
export default class extends Controller {
  select (event) {
    const link = event.currentTarget
    if (!link.href) return
    event.preventDefault()
    const linkUrl = new URL(link.href, window.location.origin)
    const newUrl = new URL(window.location.href)
    linkUrl.searchParams.forEach((value, key) => {
      newUrl.searchParams.set(key, value)
    })
    window.location.href = newUrl.pathname + newUrl.search
  }
}
