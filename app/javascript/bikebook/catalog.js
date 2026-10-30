import { html, nothing } from 'lit-html'
import { numberDisplay, uuid } from 'bikebook/templates/helpers'
import { dragHandle } from 'bikebook/templates/ui/drag_handle'
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
    const { vocabulary, kit, options, comparable } = await call('load', {
      manifestUrl: new URL(manifestUrl, window.location.href).href,
      ids,
      jurisdictions,
      rulesUrl: import.meta.resolve('bikebook/featured_rules'),
      similarityUrl: import.meta.resolve('bikebook/similarity')
    })
    return {
      vocabulary,
      kit,
      options,
      comparable,
      // null, as for a comparison format it doesn't know, where the comparison doesn't load
      similar: (model, settings, filters) => call('similar', { model, settings, filters }).catch((error) => {
        console.error(error)
        return null
      }),
      search: (params, page, perPage) => call('search', { params, page, perPage }),
      featured: (params, legalClasses) => call('featured', { params, legalClasses }),
      group: (id) => call('group', { model: id }),
      vehicles: (ids, { market } = {}) => call('vehicles', { ids, market }),
      displays: (ids) => call('displays', { ids })
    }
  } catch (error) {
    worker.terminate()
    throw error
  }
}

// Answers a hotwire_combobox async filter with the markup the gem's own turbo-stream response would
// carry, so its selection and paging run unchanged
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
    // The gem settles a pending filter only on an input type, as its own request falls back to
    await this.#render(combobox, 0, { inputType: primed ? undefined : inputType || 'hw:unspecifiedInput', primed })
  }

  // The gem fetches the first page through a lazy turbo-frame on first open; list it here instead
  prime (combobox) {
    return this.filter(combobox, undefined, { primed: true })
  }

  async #render (combobox, page, { inputType, primed }) {
    const generation = this.#generation
    const { total, filteredCount, unfiltered, models, nextPage } = await this.catalog.search(this.params, page, this.catalog.kit.per_page)
    if ((page && generation !== this.#generation) || !combobox.element.isConnected) return

    const forId = combobox.element.dataset.asyncId
    const listbox = combobox._actingListbox
    const picked = String(this.params.vehicle_models ?? '').split(',')
    const { kit, vocabulary } = this.catalog
    const options = models.map((model) => comboboxOption({
      model,
      selected: picked.includes(model.id),
      placeholderUrl: kit.placeholder_url,
      currencies: vocabulary.currencies,
      market: this.params.market,
      configurations: kit.model_configurations
    }))
    const pagination = html`<li id=${`${forId}__hw_combobox_pagination__wrapper`} class="hw_combobox__pagination__wrapper"
      data-hw-combobox-target="endOfOptionsStream" data-input-type=${inputType ?? nothing} aria-hidden="true"></li>`
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

  // No chip for an id the catalog lacks, nor for one already chipped unless `adding` it as a repeat pick
  async chips (combobox, values, { adding = false } = {}) {
    const chipped = new Set([...combobox.element.querySelectorAll('[data-hw-combobox-value-param]')].map((remover) => remover.dataset.hwComboboxValueParam))
    const ids = String(values).split(',').filter((id) => id && (adding || !chipped.has(id)))
    if (ids.length === 0) return

    const displays = await this.catalog.displays(ids)
    if (!combobox.element.isConnected) return

    const classifications = this.catalog.vocabulary.e_vehicle_classifications
    renderChips(combobox.element, ids.map((value, index) => ({ value, display: displays[index] ?? classifications[value]?.label }))
      .filter(({ display }) => display != null))
  }
}

// The gem's selection chip partial, ahead of the field, gripped where bikebook--chip-reorder drags them
export const renderChips = (combobox, chips) => {
  const handle = combobox.matches('[data-controller~="bikebook--chip-reorder"]') ? dragHandle({ controller: 'bikebook--chip-reorder', htmlClass: 'tw:mr-1' }) : nothing
  combobox.querySelector('[data-hw-combobox-target~="combobox"]').before(fragmentOf(chips.map(({ value, display }) =>
    html`<div data-hw-combobox-chip=""><div class="hw-combobox__chip">${handle}<span>${display}</span><span tabindex="0" class="hw-combobox__chip__remover"
      aria-label=${`Remove ${display}`} data-action="click->hw-combobox#removeChip:stop keydown->hw-combobox#navigateChip"
      data-hw-combobox-target="chipDismisser" data-hw-combobox-value-param=${value}></span></div></div>`)))
}

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
