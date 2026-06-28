import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='lexxy'
// Lazily loads the Lexxy editor bundle and its gem stylesheet only on pages that use it (both are
// large / gem-served). Importing the module registers the <lexxy-editor> custom element, upgrading
// every editor on the page; the stylesheet is injected once (deduped by href) so the editor works
// without wiring lexxy.css into the layout. Multiple editors can each carry the controller -- the
// module import is cached and the stylesheet inject is a no-op after the first.
export default class extends Controller {
  static values = { stylesheet: String }

  connect () {
    import('lexxy')
    this.#addStylesheet()
  }

  #addStylesheet () {
    const href = this.stylesheetValue
    if (!href || document.querySelector(`link[rel="stylesheet"][href="${href}"]`)) return

    const link = document.createElement('link')
    link.rel = 'stylesheet'
    link.href = href
    document.head.appendChild(link)
  }
}
