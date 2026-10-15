import { Controller } from '@hotwired/stimulus'
import { readable, replaceUrl } from 'bikebook/replace_url'

/* global CSS */

// Threads the filter panel's values into the vehicle combobox's async src and mirrors them
// into the page URL, which the page renders the controls from (ui--collapse owns ?filters)
export default class extends Controller {
  static targets = ['vehicleCombobox', 'yearArrow', 'priceArrow', 'summary', 'field', 'classification', 'clear']
  static values = {
    yearDir: { type: String, default: 'desc' },
    priceDir: { type: String, default: 'desc' },
    defaultMarket: String,
    defaultJurisdiction: String
  }

  // Rewritten on connect too, as rendering drops stale values. Not from the loading placeholder,
  // whose empty fields would clear the URL's filters
  connect () {
    this.yearArrowTarget.textContent = this.#arrow(this.yearDirValue)
    this.priceArrowTarget.textContent = this.#arrow(this.priceDirValue)
    this.#showClasses()
    this.#refreshSummary()
    if (!this.element.closest('[inert]')) this.#writeUrl()
  }

  toggleSort ({ params: { field } }) {
    const dir = `${field}DirValue`
    this[dir] = this[dir] === 'desc' ? 'asc' : 'desc'
    this[`${field}ArrowTarget`].textContent = this.#arrow(this[dir])
    this.apply()
  }

  apply () {
    this.#showClasses()
    this.#syncCombobox()
    this.#refreshSummary()
    this.#writeUrl()
  }

  // A multiselect fires hw-combobox:selection before it writes the hidden field,
  // so defer a tick to read the picked value.
  applySelection () {
    setTimeout(() => this.apply(), 0)
  }

  // The classes are the US market's, by state - a state without its own uses the US ones - and a hidden
  // class doesn't stay checked
  #showClasses () {
    const { market, jurisdiction } = this.#filters
    const groups = [...this.classificationTarget.querySelectorAll('[data-jurisdiction]')]
    const shown = market === 'US' && (groups.find(({ dataset }) => dataset.jurisdiction === jurisdiction) ?? groups[0])
    this.classificationTarget.classList.toggle('tw:hidden', !shown)
    for (const group of groups) {
      const hidden = group !== shown
      group.classList.toggle('tw:hidden', hidden)
      if (hidden) for (const input of group.querySelectorAll('input')) input.checked = false
    }
  }

  #syncCombobox () {
    const fieldset = this.vehicleComboboxTarget.querySelector('.hw-combobox')
    const url = new URL(fieldset.dataset.hwComboboxAsyncSrcValue, window.location.origin)
    this.#applyParams(url)
    fieldset.dataset.hwComboboxAsyncSrcValue = url.pathname + url.search
    // disabled while the catalog loads, which has nothing to search yet
    const input = fieldset.querySelector('.hw-combobox__input')
    if (!input.disabled) input.dispatchEvent(new Event('input', { bubbles: true }))
  }

  // The URL leaves out the default market and jurisdiction, so a shared link opens in its reader's own -
  // but not a jurisdiction with a class checked, which another's would hide and uncheck
  #writeUrl () {
    const url = new URL(window.location)
    const filters = this.#filters
    const jurisdiction = filters.jurisdiction || 'US'
    const classChecked = this.classificationTarget.querySelector('input:checked')
    this.#applyParams(url, {
      ...filters,
      market: filters.market === this.defaultMarketValue ? '' : filters.market || 'all',
      jurisdiction: jurisdiction === this.defaultJurisdictionValue && !classChecked ? '' : jurisdiction
    })
    replaceUrl(url)
    this.refreshClear()
  }

  // A clear link's href: this page less its filters but the market, which it renders afresh at their defaults. Set
  // again as it's clicked, since the panel's own state and the picks reach the URL without a filter changing
  refreshClear () {
    const url = new URL(window.location)
    for (const name of [...Object.keys(this.#filters), 'jurisdiction'].filter((name) => name !== 'market')) url.searchParams.delete(name)
    for (const link of this.clearTargets) link.href = readable(url)
  }

  #applyParams (url, filters = this.#filters) {
    const params = {
      ...filters,
      year_dir: this.yearDirValue === 'asc' ? 'asc' : '',
      price_dir: this.priceDirValue === 'asc' ? 'asc' : ''
    }
    for (const [key, value] of Object.entries(params)) value ? url.searchParams.set(key, value) : url.searchParams.delete(key)
  }

  // a clear keeps the market and returns the default jurisdiction, so neither alone leaves anything to clear
  #refreshSummary () {
    const { market, jurisdiction, ...filters } = this.#filters
    const filtered = Object.values(filters).some(Boolean) || (jurisdiction || 'US') !== this.defaultJurisdictionValue
    for (const link of this.clearTargets) link.hidden = !filtered
    this.summaryTarget.replaceChildren(...this.#summary.map(([label, value]) => {
      const item = document.createElement('li')
      const name = document.createElement('strong')
      name.textContent = `${label}: `
      item.append(name, value)
      return item
    }))
  }

  // Market is left out, as every visit starts with one
  get #summary () {
    return this.fieldTargets.filter((field) => !field.querySelector('input[name="market"]'))
      .map((field) => [field.dataset.filterLabel, this.#describe(field)])
      .filter(([, value]) => value)
  }

  #describe (field) {
    const inputs = [...field.querySelectorAll('input[name]')]
    if (field.matches('.hw-combobox')) {
      return inputs[0].value.split(',').filter(Boolean)
        .map((value) => field.querySelector(`[role="option"][data-value="${CSS.escape(value)}"]`)?.dataset.autocompletableAs ?? value)
        .join(', ')
    }
    const boxes = inputs.filter(({ type }) => type === 'checkbox')
    if (boxes.length) {
      const checked = boxes.filter(({ checked }) => checked).map(({ labels }) => labels[0].textContent.trim()).join(', ')
      // a state stands alone, read from its option, as the combobox may not have filled its input yet
      const jurisdiction = field.querySelector('input[name="jurisdiction"]')
      if (!jurisdiction || field.classList.contains('tw:hidden')) return checked
      const state = jurisdiction.value && field.querySelector(`[role="option"][data-value="${CSS.escape(jurisdiction.value)}"]`)
        ?.dataset.autocompletableAs.replace(/ \(\w+\)$/, '')
      return checked ? `${checked} (${state || field.querySelector('[role="combobox"]').placeholder})` : state
    }
    const [min, max] = inputs.map(({ value }) => value && `${field.dataset.filterPrefix}${value}`)
    if (min && max) return `${min}–${max}`
    return min ? `from ${min}` : max && `up to ${max}`
  }

  // A set of checkboxes is one comma-joined value, blank when none is checked
  get #filters () {
    const inputs = this.fieldTargets.flatMap((field) => [...field.querySelectorAll('input[name]')])
    return Object.fromEntries([...new Set(inputs.map(({ name }) => name))].map((name) => [name, inputs
      .filter((input) => input.name === name && (input.type !== 'checkbox' || input.checked))
      .map(({ value }) => value).join(',')]))
  }

  #arrow (dir) {
    return dir === 'asc' ? '↑' : '↓'
  }
}
