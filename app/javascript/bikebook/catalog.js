import { html, nothing } from 'lit-html'
import { numberDisplay, uuid } from 'bikebook/templates/helpers'
import { classificationOption } from 'bikebook/templates/vehicles/class_cards'
import { comboboxOption } from 'bikebook/templates/vehicles/combobox_option'
import { fragmentOf, renderInto } from 'bikebook/render'

/* global IntersectionObserver, Worker */

// `jurisdictions` names the codes classifications are in, which the catalog doesn't
export async function loadCatalog (manifestUrl, ids = [], jurisdictions = {}) {
  const worker = new Worker(import.meta.resolve('bikebook/catalog_worker'), { type: 'module' })
  const pending = new Map()
  let nextId = 0
  worker.onmessage = ({ data: { id, result, error } }) => {
    const { resolve, reject } = pending.get(id)
    pending.delete(id)
    error ? reject(new Error(error)) : resolve(result)
  }
  worker.onerror = worker.onmessageerror = ({ message }) => {
    pending.forEach(({ reject }) => reject(new Error(message || "The catalog's worker failed")))
    pending.clear()
  }
  const call = (type, args) => new Promise((resolve, reject) => {
    pending.set(nextId, { resolve, reject })
    worker.postMessage({ id: nextId++, type, ...args })
  })

  try {
    const { vocabulary, kit, options } = await call('load', {
      manifestUrl: new URL(manifestUrl, window.location.href).href, ids, jurisdictions, rulesUrl: import.meta.resolve('bikebook/featured_rules')
    })
    return {
      vocabulary,
      kit,
      options,
      search: (params, page, perPage) => call('search', { params, page, perPage }),
      featured: (params, legalClasses) => call('featured', { params, legalClasses }),
      vehicles: (ids) => call('vehicles', { ids }),
      displays: (ids) => call('displays', { ids })
    }
  } catch (error) {
    worker.terminate()
    throw error
  }
}

// Answers a hotwire_combobox async filter with the markup the gem's own turbo-stream response would
// carry, so its callbacks and paging run unchanged
export class CatalogComboboxSource {
  #generation = 0

  // onSearch takes each search's params, its count of results and of the models its filters match, and whether it
  // primed the listing rather than answered the reader
  constructor (catalog, onSearch = () => {}) {
    this.catalog = catalog
    this.onSearch = onSearch
  }

  // A pick re-renders the page, leaving the gem's debounced refilter behind on the combobox it replaced
  async filter (combobox, inputType, { primed = false } = {}) {
    if (!combobox.element.isConnected) return

    const query = new URL(combobox.asyncSrcValue, window.location.origin).searchParams
    this.params = { ...Object.fromEntries(query), q: combobox._fullQuery }
    this.#generation++
    await this.#render(combobox, 0, { inputType, primed, callbackId: primed ? undefined : combobox._enqueueCallback() })
  }

  // The gem fetches the first page through a lazy turbo-frame on first open; list it here instead
  prime (combobox) {
    return this.filter(combobox, undefined, { primed: true })
  }

  async #render (combobox, page, { inputType, callbackId, primed }) {
    const generation = this.#generation
    const { total, filteredCount, unfiltered, models, nextPage } = await this.catalog.search(this.params, page, this.catalog.kit.per_page)
    if ((page && generation !== this.#generation) || !combobox.element.isConnected) return

    const forId = combobox.element.dataset.asyncId
    const listbox = combobox._actingListbox
    const options = models.map((model) => comboboxOption({ model, placeholderUrl: this.catalog.kit.placeholder_url, currencies: this.catalog.vocabulary.currencies }))
    const pagination = html`<li id=${`${forId}__hw_combobox_pagination__wrapper`} class="hw_combobox__pagination__wrapper"
      data-hw-combobox-target="endOfOptionsStream" data-input-type=${inputType ?? nothing} data-callback-id=${callbackId ?? nothing} aria-hidden="true"></li>`
    document.getElementById(`${forId}__hw_combobox_pagination__wrapper`)?.remove()
    if (page === 0) {
      const offered = classificationOption(this.params.q, String(this.params.vehicle_models ?? '').split(','), this.catalog.vocabulary.e_vehicle_classifications)
      listbox.replaceChildren(fragmentOf(html`${offered ? group('E-bike classification', [offered]) : nothing}${
        group(unfiltered ? unmatched : matching(total), options)}${pagination}`))
      this.onSearch({ params: this.params, total, filteredCount, primed })
    } else {
      listbox.append(fragmentOf(html`${options}${pagination}`))
    }
    if (nextPage) this.#paginate(combobox, nextPage, listbox.lastElementChild)
  }

  // Stands in for the gem's lazy pagination frame; a page asked for after the query changed
  // belongs to a listing already replaced
  #paginate (combobox, page, wrapper) {
    const generation = this.#generation
    const observer = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting) return

      observer.disconnect()
      if (generation === this.#generation) this.#render(combobox, page, {})
    })
    observer.observe(wrapper)
  }

  // An id the catalog lacks gets no chip, and one the render already chipped no second
  async chips (combobox, values) {
    const chipped = new Set([...combobox.element.querySelectorAll('[data-hw-combobox-value-param]')].map((remover) => remover.dataset.hwComboboxValueParam))
    const ids = String(values).split(',').filter((id) => id && !chipped.has(id))
    if (ids.length === 0) return

    const displays = await this.catalog.displays(ids)
    if (!combobox.element.isConnected) return

    const classifications = this.catalog.vocabulary.e_vehicle_classifications
    renderChips(combobox.element, ids.map((value, index) => ({ value, display: displays[index] ?? classifications[value]?.label }))
      .filter(({ display }) => display != null))
  }
}

// The gem's selection chip partial, ahead of the field
export const renderChips = (combobox, chips) => combobox.querySelector('[data-hw-combobox-target~="combobox"]').before(fragmentOf(chips.map(({ value, display }) =>
  html`<div data-hw-combobox-chip=""><div class="hw-combobox__chip"><span>${display}</span><span tabindex="0" class="hw-combobox__chip__remover"
    aria-label=${`Remove ${display}`} data-action="click->hw-combobox#removeChip:stop keydown->hw-combobox#navigateChip"
    data-hw-combobox-target="chipDismisser" data-hw-combobox-value-param=${value}></span></div></div>`)))

const group = (label, options) => {
  const id = uuid()
  return html`<ul class="hw-combobox__group" role="group" aria-labelledby=${id}><li id=${id} class="hw-combobox__group__label"
    role="presentation">${label}</li>${options}</ul>`
}

export const renderCounts = (root, count) => renderInto(root.getElementById('vehicle-models-count'), matching(count))

// in UI::Alerts::Base's warning colors
const unmatched = html`<span class="tw:rounded-sm tw:border tw:border-yellow-300 tw:bg-yellow-50 tw:px-1 tw:text-yellow-800
  tw:dark:border-yellow-800 tw:dark:bg-yellow-950 tw:dark:text-yellow-400">(model doesn't match filters)</span>`

export const matching = (count) => html`(${numberDisplay(count)} matching ${count === 1 ? 'model' : 'models'})`
