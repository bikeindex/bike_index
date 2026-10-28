import { Controller } from '@hotwired/stimulus'
import { CatalogComboboxSource, loadCatalog, renderCounts } from 'bikebook/catalog'
import { hydrate, loadingShell, pickedVehicles, rescoredSimilar, unpickedVehicles } from 'bikebook/hydrate'
import { keepPermanent, renderInto } from 'bikebook/render'
import { readable } from 'bikebook/replace_url'
import { searching } from 'bikebook/query'
import { collapse } from 'utils/collapse_utils'
import { SearchLog } from 'bikebook/search_log'
import { realigned, storePreferredSize, withSize } from 'bikebook/sizes'
import { renderClassCards, withClassifications } from 'bikebook/templates/vehicles/class_cards'
import { uuid } from 'bikebook/templates/helpers'

/* global CSS, requestAnimationFrame */

const stamped = (state) => ({ ...state, bikebook: uuid() })

// Connects to data-controller='bikebook--page'
// Searches and compares the published catalog in the browser. A pick submits the form, and it, a
// link to this page and each history step render the page afresh from the shell, without a request
export default class extends Controller {
  static targets = ['shell', 'page', 'status']
  static values = { manifestUrl: String, jurisdictions: Object, failedText: String, title: String, searchLogUrl: String }

  #scrolls = new Map()
  #searchLog
  #renders = 0
  #refilters = 0
  #rescores = 0
  #renderedUrl

  // The loading shell holds the status until the catalog's first render replaces it, and a failure puts it back
  initialize () {
    this.status = this.statusTarget
    this.#searchLog = new SearchLog(this.searchLogUrlValue)
  }

  async connect () {
    window.history.scrollRestoration = 'manual'
    this.#stamp()
    const url = new URL(window.location.href)
    this.#render(url)
    try {
      this.catalog = await loadCatalog(this.manifestUrlValue, url.searchParams.get('vehicle_models')?.split(',') ?? [], this.jurisdictionsValue)
    } catch (error) {
      return this.#fail(error)
    }
    // the URL's filters are the reader's, where the combobox's add the visitor's market
    this.source = new CatalogComboboxSource(this.catalog, ({ params: { q, vehicle_models: picked = '' }, total, filteredCount, primed }) => {
      renderCounts(document, filteredCount)
      // a jurisdiction's change searches again, moving the cards to its own
      renderClassCards(document, picked.split(','), this.catalog.vocabulary.e_vehicle_classifications)
      if (!primed) this.#searchLog.typed({ ...Object.fromEntries(new URL(window.location.href).searchParams), q, count: total })
    })
    // filters set while it loaded are in the URL, and the reader stays where they've scrolled to
    const current = new URL(window.location.href)
    this.#render(current, [window.scrollX, window.scrollY])
    this.#searchLog.visited(current)
  }

  // The form's fields over the URL's other params, such as an open panel's, its sizes following their vehicles,
  // rendered where the reader is: a pick or a chip's removal is no new page
  visit (event) {
    event.preventDefault()
    const url = new URL(window.location.href)
    new FormData(event.target).forEach((value, name) => url.searchParams.set(name, value))
    this.#go(realigned(withClassifications(url, this.catalog.vocabulary.e_vehicle_classifications)), [window.scrollX, window.scrollY])
  }

  // A plain click on a link to this page, such as a card's remove link, or on a drawing's figure's data-href, which an
  // in-place link renders without scrolling, focusing what the data-in-place on it or an ancestor selects rather than the search, and one inside a
  // data-replace in place of the history entry it's on. One among the vehicles was written when the page rendered, so
  // only what it changes from that goes onto the URL, which filters and panels have moved on since
  follow (event) {
    const link = event.target.closest('a[href], [data-href]')
    if (!link || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || link.target) return

    const url = new URL(link.getAttribute('href') ?? link.dataset.href, window.location.href)
    if (url.origin !== window.location.origin || url.pathname !== window.location.pathname) return

    event.preventDefault()
    const inPlace = link.closest('[data-in-place]')
    if (!inPlace) return this.#go(url)

    const next = link.closest('#vehicle-viewers') ? this.#changedBy(url) : url
    // one that shows the search a lone model hid, as its tab does, is a step back can undo, and opens and focuses it
    const reveal = !searching(new URL(window.location.href)) && searching(next)
    this.#go(next, [window.scrollX, window.scrollY], {
      focus: reveal ? '[autofocus]' : inPlace.dataset.inPlace || false, replace: Boolean(link.closest('[data-replace]')) && !reveal, reveal
    })
  }

  // A comparison table's size, which the others follow when it's the first vehicle's, and which a later
  // comparison's first vehicle starts nearest
  async pickSize ({ target, params: { vehicle, first } }) {
    if (first) storePreferredSize(JSON.parse(target.selectedOptions[0].dataset.size))
    await this.#go(withSize(new URL(window.location.href), vehicle, target.value), [window.scrollX, window.scrollY])
    this.pageTarget.querySelector(`select[data-bikebook--page-vehicle-param="${CSS.escape(vehicle)}"]`)?.focus({ preventScroll: true })
  }

  // A filter changes in place, which with nothing picked the featured models and their count follow, and the picked
  // ones a jurisdiction or market, which decide which are out of class, which are sold elsewhere and which similar ones
  // show, or the filters opening, which hold the similar models' adjustments while they're open, unless the page renders
  // or the filters change again first
  async refilter () {
    const viewers = this.pageTarget.querySelector('#vehicle-viewers')
    const url = new URL(window.location.href)
    const unpicked = viewers?.querySelector(':scope > [data-controller~="bikebook--tips"]')
    const placeChanged = ['jurisdiction', 'market', 'market_scope', 'filters'].some((name) => url.searchParams.get(name) !== this.#renderedUrl?.searchParams.get(name))
    if (!this.catalog || !viewers || (!unpicked && !placeChanged)) return

    const render = this.#renders
    const refilter = ++this.#refilters
    const { vehicles, adjustments } = await (unpicked ? unpickedVehicles : pickedVehicles)(this.catalog, this.pageTarget, url)
    if (render === this.#renders && refilter === this.#refilters) {
      renderInto(viewers, vehicles)
      renderInto(this.pageTarget.querySelector('#similar-adjustments'), adjustments)
      this.#renderedUrl = url
    }
  }

  // the filters' panel opening or closing moves the similar models' adjustments, once there are any
  toggleFilters ({ target }) {
    if (target.getAttribute('data-ui--collapse-param-value') === 'filters' && this.pageTarget.querySelector('#similar-toggle')) this.refilter()
  }

  // The page as it is, rendered where the reader is, such as once a section that's scored when open first opens
  refresh () {
    this.#render(new URL(window.location.href), [window.scrollX, window.scrollY], { focus: false })
  }

  // The similar models' section opened from a toggle outside it, its own toggle taking focus
  compareSimilar () {
    const toggle = this.pageTarget.querySelector('#similar-toggle')
    toggle.click()
    toggle.focus()
  }

  // The similar models by the settings their controls set, unless the page renders or they change again first
  async rescore ({ detail: { vehicle, settings } }) {
    const render = this.#renders
    const rescore = ++this.#rescores
    const results = await rescoredSimilar(this.catalog, this.pageTarget, new URL(window.location.href), vehicle, settings)
    if (render === this.#renders && rescore === this.#rescores) renderInto(this.pageTarget.querySelector('#similar-results'), results)
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

  #changedBy (link) {
    const url = new URL(window.location.href)
    const rendered = this.#renderedUrl ?? url
    for (const name of new Set([...link.searchParams.keys(), ...rendered.searchParams.keys()])) {
      const value = link.searchParams.get(name)
      if (value === rendered.searchParams.get(name)) continue
      value === null ? url.searchParams.delete(name) : url.searchParams.set(name, value)
    }
    return url
  }

  #go (url, scroll = [0, 0], { replace = false, ...options } = {}) {
    window.history[replace ? 'replaceState' : 'pushState'](stamped(), '', readable(url))
    this.#searchLog.visited(url)
    return this.#render(url, scroll, options)
  }

  // `focus` selects what to focus, the search where it selects nothing, unless a field of the page's has focus, which
  // keeps it and any value it hasn't yet changed to. Until the catalog loads, the page is its loading shell
  async #render (url, scroll, { focus = '[autofocus]', reveal = false } = {}) {
    if (!this.catalog) return this.pageTarget.replaceChildren(loadingShell(this.shellTarget, url, this.status))

    const render = ++this.#renders
    // A share menu shares the canonical, which names the page the server sent. Kept through the first render, which crawlers see
    if (render > 1) document.querySelector('link[rel="canonical"]')?.remove()
    const rendered = await hydrate(this.catalog, this.source, this.shellTarget, url).catch((error) => error)
    if (render !== this.#renders) return
    if (rendered instanceof Error) return this.#fail(rendered)

    // what turbo:before-render is to a Turbo page, which an open combobox dialog closes on
    this.dispatch('before-render')
    const active = this.pageTarget.contains(document.activeElement) && document.activeElement.id ? document.activeElement : null
    this.pageTarget.replaceChildren(keepPermanent(rendered.content, this.pageTarget))
    if (reveal) {
      const search = this.pageTarget.querySelector('[data-controller~="bikebook--catalog-filters"]')
      search.classList.add('tw:hidden')
      collapse('show', search)
    }
    this.#renderedUrl = url
    document.title = rendered.title ?? this.titleValue
    const kept = active && this.pageTarget.querySelector(`#${CSS.escape(active.id)}`)
    if (kept) {
      if (['text', 'number', 'search'].includes(active.type)) kept.value = active.value
      // once its panel's controller has opened it, a hidden field taking no focus
      requestAnimationFrame(() => kept.focus({ preventScroll: true }))
    } else if (focus) {
      (this.pageTarget.querySelector(focus) ?? this.pageTarget.querySelector('[autofocus]'))?.focus({ preventScroll: Boolean(scroll) })
    }
    if (scroll) {
      window.scrollTo(...scroll)
      // and again once the panels' controllers have opened them, which the browser's scroll anchoring follows down
      requestAnimationFrame(() => window.scrollTo(...scroll))
    }
  }

  // in place of the spinner, below the loading shell's search, where it's still showing
  #fail (error) {
    console.error(error)
    this.status.textContent = this.failedTextValue
    for (const input of this.pageTarget.querySelectorAll('[data-awaiting-catalog]')) input.placeholder = ''
    if (!this.pageTarget.contains(this.status)) this.pageTarget.replaceChildren(this.status)
  }
}
