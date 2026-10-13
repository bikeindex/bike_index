import { Controller } from '@hotwired/stimulus'
import { CatalogComboboxSource, loadCatalog, matching } from 'bikebook/catalog'
import { hydrate } from 'bikebook/hydrate'
import { renderInto } from 'bikebook/render'
import { readable } from 'bikebook/replace_url'
import { realigned, storePreferredSize, withSize } from 'bikebook/sizes'
import { uuid } from 'bikebook/templates/helpers'

/* global CSS */

const stamped = (state) => ({ ...state, bikebook: uuid() })

// Connects to data-controller='bikebook--page'
// Searches and compares the published catalog in the browser. A pick submits the form, and it, a
// link to this page and each history step render the page afresh from the shell, without a request
export default class extends Controller {
  static targets = ['shell', 'page', 'status', 'tagline', 'countedTagline']
  static values = { manifestUrl: String, jurisdictions: Object, failedText: String, title: String }

  #scrolls = new Map()
  #renders = 0

  // The first render replaces the status, and a failed one puts it back
  initialize () {
    this.status = this.statusTarget
  }

  async connect () {
    window.history.scrollRestoration = 'manual'
    this.#stamp()
    const url = new URL(window.location.href)
    try {
      this.catalog = await loadCatalog(this.manifestUrlValue, url.searchParams.get('vehicle_models')?.split(',') ?? [], this.jurisdictionsValue)
    } catch (error) {
      return this.#fail(error)
    }
    this.source = new CatalogComboboxSource(this.catalog, (count) => renderInto(document.getElementById('vehicle-models-count'), matching(count)))
    this.#countModels()
    this.#render(url)
  }

  // The form's fields over the URL's other params, such as an open panel's, its sizes following their vehicles
  visit (event) {
    event.preventDefault()
    const url = new URL(window.location.href)
    new FormData(event.target).forEach((value, name) => url.searchParams.set(name, value))
    this.#go(realigned(url))
  }

  // A plain click on a link to this page, such as a card's remove link, which an in-place link renders without
  // scrolling or focusing the search
  follow (event) {
    const link = event.target.closest('a[href]')
    if (!link || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || link.target) return

    const url = new URL(link.href)
    if (url.origin !== window.location.origin || url.pathname !== window.location.pathname) return

    event.preventDefault()
    'inPlace' in link.dataset ? this.#go(url, [window.scrollX, window.scrollY], { focus: false }) : this.#go(url)
  }

  // A comparison table's size, which the others follow when it's the first vehicle's, and which a later
  // comparison's first vehicle starts nearest
  async pickSize ({ target, params: { vehicle, first } }) {
    if (first) storePreferredSize(JSON.parse(target.selectedOptions[0].dataset.size))
    await this.#go(withSize(new URL(window.location.href), vehicle, target.value), [window.scrollX, window.scrollY])
    this.pageTarget.querySelector(`select[data-bikebook--page-vehicle-param="${CSS.escape(vehicle)}"]`)?.focus({ preventScroll: true })
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

  #go (url, scroll = [0, 0], options) {
    window.history.pushState(stamped(), '', readable(url))
    return this.#render(url, scroll, options)
  }

  async #render (url, scroll, { focus = true } = {}) {
    const render = ++this.#renders
    // A share menu shares the canonical, which names the page the server sent. Kept through the first render, which crawlers see
    if (render > 1) document.querySelector('link[rel="canonical"]')?.remove()
    const rendered = await hydrate(this.catalog, this.source, this.shellTarget, url).catch((error) => error)
    if (render !== this.#renders) return
    if (rendered instanceof Error) return this.#fail(rendered)

    // what turbo:before-render is to a Turbo page, which an open combobox dialog closes on
    this.dispatch('before-render')
    this.pageTarget.replaceChildren(rendered.content)
    document.title = rendered.title ?? this.titleValue
    if (focus) this.pageTarget.querySelector('[autofocus]')?.focus()
    if (scroll) window.scrollTo(...scroll)
  }

  // down to the thousand (a smaller catalog's leading place), so the tagline stays true as the catalog grows
  #countModels () {
    const { modelsCount } = this.catalog
    const place = 10 ** Math.min(3, String(modelsCount).length - 1)
    const tagline = this.countedTaglineTarget.content.cloneNode(true)
    tagline.querySelector('[data-models-count]').textContent = (Math.floor(modelsCount / place) * place).toLocaleString('en-US')
    this.taglineTarget.replaceChildren(tagline)
  }

  #fail (error) {
    console.error(error)
    this.status.textContent = this.failedTextValue
    this.pageTarget.replaceChildren(this.status)
  }
}
