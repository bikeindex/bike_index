import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--chart-card-scope-links'
// The card renders outside the frame a search replaces, so its scope links would keep
// the search they were rendered with. The address bar has the current one.
export default class extends Controller {
  connect () {
    this.updateLinks()
    document.addEventListener('turbo:frame-render', this.updateLinks)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.updateLinks)
  }

  updateLinks = () => {
    const base = new URL(window.location.href)
    // The server's scope paths leave page out, so the address bar's goes too
    base.searchParams.delete('page')

    this.element.querySelectorAll('a').forEach((link) => {
      const url = new URL(base)
      url.searchParams.set('chart_scope', new URL(link.href).searchParams.get('chart_scope'))
      link.href = url.pathname + url.search
    })
  }
}
