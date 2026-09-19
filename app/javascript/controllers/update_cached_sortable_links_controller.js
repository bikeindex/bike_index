import { Controller } from '@hotwired/stimulus'

/* global window */

// Connects to data-controller='update-cached-sortable-links'
//
// Rebuilds links whose href was rendered against a search that has since moved on: a
// fragment-cached table header, or a row that renders outside the frame a search replaces.
export default class extends Controller {
  static values = {
    // Where the search is now. Defaults to the address bar, which is where a frame
    // navigation leaves it.
    baseUrl: String,
    selector: { type: String, default: 'a.display-sortable-link' },
    // The params the link brings; the rest come from the base. Empty brings them all.
    linkParams: Array
  }

  connect () {
    this.updateLinks()
    document.addEventListener('turbo:frame-render', this.updateLinks)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.updateLinks)
  }

  updateLinks = () => {
    const baseUrl = new URL(this.hasBaseUrlValue ? this.baseUrlValue : window.location.href, window.location.origin)
    // sortable_search_params leaves page out, so neither does the address bar standing in for it
    baseUrl.searchParams.delete('page')

    this.element.querySelectorAll(this.selectorValue).forEach(link => {
      const linkUrl = new URL(link.href, window.location.origin)
      const newUrl = new URL(baseUrl)

      linkUrl.searchParams.forEach((value, key) => {
        if (this.linkParamsValue.length && !this.linkParamsValue.includes(key)) return
        newUrl.searchParams.set(key, value)
      })

      link.href = newUrl.pathname + newUrl.search
    })
  }
}
