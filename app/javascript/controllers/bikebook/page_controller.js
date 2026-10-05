import { Controller } from '@hotwired/stimulus'
import { CatalogComboboxSource, loadCatalog } from 'bikebook/catalog'
import { hydrate } from 'bikebook/hydrate'
import { uuid } from 'bikebook/templates/helpers'

const stamped = (state) => ({ ...state, bikebook: uuid() })

// Connects to data-controller='bikebook--page'
// Searches and compares the published catalog in the browser. A pick submits the form, and it, a
// link to this page and each history step render the page afresh from the shell, without a request
export default class extends Controller {
  static targets = ['shell', 'page', 'status']
  static values = { manifestUrl: String, failedText: String }

  #scrolls = new Map()
  #renders = 0

  // The first render replaces the status, and a failed one puts it back
  initialize () {
    this.status = this.statusTarget
    this.title = document.title
  }

  async connect () {
    window.history.scrollRestoration = 'manual'
    this.#stamp()
    const url = new URL(window.location.href)
    try {
      this.catalog = await loadCatalog(this.manifestUrlValue, url.searchParams.get('vehicle_models')?.split(',') ?? [])
    } catch (error) {
      return this.#fail(error)
    }
    const { kit } = this.catalog
    this.source = new CatalogComboboxSource(this.catalog, { placeholderUrl: kit.placeholder_url, perPage: kit.per_page })
    this.#render(url)
  }

  // The form's fields over the URL's other params, such as an open panel's
  visit (event) {
    event.preventDefault()
    const url = new URL(window.location.href)
    new FormData(event.target).forEach((value, name) => url.searchParams.set(name, value))
    this.#go(url)
  }

  // A plain click on a link to this page, such as a card's remove link
  follow (event) {
    const link = event.target.closest('a[href]')
    if (!link || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || link.target) return

    const url = new URL(link.href)
    if (url.origin !== window.location.origin || url.pathname !== window.location.pathname) return

    event.preventDefault()
    this.#go(url)
  }

  restore () {
    this.#stamp()
    this.#render(new URL(window.location.href), this.#scrolls.get(this.#entry) ?? [0, 0])
  }

  track () {
    this.#scrolls.set(this.#entry, [window.scrollX, window.scrollY])
  }

  get #entry () {
    return window.history.state?.bikebook
  }

  #stamp () {
    if (!this.#entry) window.history.replaceState(stamped(window.history.state), '')
  }

  #go (url) {
    window.history.pushState(stamped(), '', url)
    this.#render(url, [0, 0])
  }

  async #render (url, scroll) {
    const render = ++this.#renders
    const rendered = await hydrate(this.catalog, this.source, this.shellTarget, url).catch((error) => error)
    if (render !== this.#renders) return
    if (rendered instanceof Error) return this.#fail(rendered)

    // what turbo:before-render is to a Turbo page, which an open combobox dialog closes on
    this.dispatch('before-render')
    this.pageTarget.replaceChildren(rendered.content)
    document.title = rendered.title ?? this.title
    this.pageTarget.querySelector('[autofocus]')?.focus()
    if (scroll) window.scrollTo(...scroll)
  }

  #fail (error) {
    console.error(error)
    this.status.textContent = this.failedTextValue
    this.pageTarget.replaceChildren(this.status)
  }
}
