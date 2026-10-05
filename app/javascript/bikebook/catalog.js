import { html, nothing } from 'lit-html'
import { numberDisplay, uuid } from 'bikebook/templates/helpers'
import { comboboxOption } from 'bikebook/templates/vehicles/combobox_option'
import { fragmentOf, renderInto } from 'bikebook/render'
import kit from 'bikebook/kit'

/* global IntersectionObserver, Worker */

export async function loadCatalog (manifestUrl, ids = []) {
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
    const { vocabulary, options } = await call('load', { manifestUrl: new URL(manifestUrl, window.location.href).href, ids })
    return {
      vocabulary,
      options,
      search: (params, page, perPage) => call('search', { params, page, perPage }),
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

  constructor (catalog, { placeholderUrl, perPage }) {
    this.catalog = catalog
    this.placeholderUrl = placeholderUrl
    this.perPage = perPage
  }

  // A pick re-renders the page, leaving the gem's debounced refilter behind on the combobox it replaced
  async filter (combobox, inputType, { callback = true } = {}) {
    if (!combobox.element.isConnected) return

    const query = new URL(combobox.asyncSrcValue, window.location.origin).searchParams
    this.params = { ...Object.fromEntries(query), q: combobox._fullQuery }
    this.#generation++
    await this.#render(combobox, 0, { inputType, callbackId: callback ? combobox._enqueueCallback() : undefined })
  }

  // The gem fetches the first page through a lazy turbo-frame on first open; list it here instead
  prime (combobox) {
    return this.filter(combobox, undefined, { callback: false })
  }

  async #render (combobox, page, { inputType, callbackId }) {
    const generation = this.#generation
    const { total, filteredCount, models, nextPage } = await this.catalog.search(this.params, page, this.perPage)
    if ((page && generation !== this.#generation) || !combobox.element.isConnected) return

    const forId = combobox.element.dataset.asyncId
    const listbox = combobox._actingListbox
    const options = models.map((model) => comboboxOption({ model, placeholderUrl: this.placeholderUrl, currencies: kit.currencies }))
    const pagination = html`<li id=${`${forId}__hw_combobox_pagination__wrapper`} class="hw_combobox__pagination__wrapper"
      data-hw-combobox-target="endOfOptionsStream" data-input-type=${inputType ?? nothing} data-callback-id=${callbackId ?? nothing} aria-hidden="true"></li>`
    document.getElementById(`${forId}__hw_combobox_pagination__wrapper`)?.remove()
    if (page === 0) {
      listbox.replaceChildren(fragmentOf(html`${group(matching(total), options)}${pagination}`))
      renderInto(document.getElementById('vehicle-models-count'), matching(filteredCount))
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

  // An id the catalog lacks gets no chip
  async chips (combobox, values) {
    const ids = String(values).split(',').filter(Boolean)
    const displays = await this.catalog.displays(ids)
    if (!combobox.element.isConnected) return

    renderChips(combobox.element, ids.map((value, index) => ({ value, display: displays[index] })).filter(({ display }) => display != null))
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

export const matching = (count) => html`(${numberDisplay(count)} matching ${count === 1 ? 'model' : 'models'})`
