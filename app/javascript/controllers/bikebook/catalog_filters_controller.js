import { Controller } from '@hotwired/stimulus'
import { ordered, RANGES } from 'bikebook/query'
import { readable, replaceUrl } from 'bikebook/replace_url'

/* global CSS */

const MARKET_FIELDS = ['market', 'market_scope']

// Threads the filter panel's values into the vehicle combobox's async src and mirrors them
// into the page URL, which the page renders the controls from (ui--collapse owns ?filters)
export default class extends Controller {
  static targets = ['vehicleCombobox', 'yearArrow', 'priceArrow', 'summary', 'field', 'classification', 'clear', 'marketScope', 'marketName']
  static values = {
    sort: { type: String, default: 'year' },
    yearDir: { type: String, default: 'desc' },
    priceDir: { type: String, default: 'desc' },
    defaultMarket: String,
    defaultJurisdiction: String
  }

  // Rewritten on connect too, as rendering drops stale values. Not from the loading placeholder,
  // whose empty fields would clear the URL's filters
  connect () {
    this.#showSort()
    this.#showMarket()
    this.#showClasses()
    this.#classifyPropulsion()
    this.#refreshSummary()
    if (!this.element.closest('[inert]')) this.#writeUrl()
  }

  // as the empty page's More filters opens the panel
  focusFirst () {
    this.element.querySelector('#vehicle-filters input:not([type=hidden])')?.focus()
  }

  toggleSort ({ params: { field } }) {
    const dir = `${field}DirValue`
    if (this.sortValue === field) this[dir] = this[dir] === 'desc' ? 'asc' : 'desc'
    this.sortValue = field
    this.#showSort()
    this.apply()
  }

  // the page follows the URL's filters
  apply () {
    this.#orderRanges()
    this.#showMarket()
    this.#showClasses()
    this.#classifyPropulsion()
    this.#syncCombobox()
    this.#refreshSummary()
    this.#writeUrl()
    this.dispatch('change')
  }

  // A multiselect fires hw-combobox:selection before it writes the hidden field,
  // so defer a tick to read the picked value.
  applySelection () {
    setTimeout(() => this.apply(), 0)
  }

  // a range typed backwards turned the way round it was meant
  #orderRanges () {
    const fields = RANGES.map((name) => this.element.querySelector(`input[name="${name}"]`))
    const values = ordered(Object.fromEntries(fields.map(({ name, value }) => [name, value])))
    for (const field of fields) field.value = values[field.name]
  }

  // How the market narrows names it, as the catalog does once it's in, and it narrows nothing without one
  #showMarket () {
    const { market } = this.#filters
    this.marketScopeTarget.hidden = !market
    const name = this.element.querySelector(`#market-hw-listbox [role="option"][data-value="${CSS.escape(market)}"]`)?.dataset.name
    if (name) for (const target of this.marketNameTargets) target.textContent = name
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

  // A checked class is an e-vehicle's, so it checks e-Vehicle (motorized) and rules out Human powered
  #classifyPropulsion () {
    const classed = this.#classes.length > 0
    const [human, motorized] = ['0', '1'].map((value) => this.element.querySelector(`input[name="electric"][value="${value}"]`))
    human.disabled = classed
    if (!classed) return

    human.checked = false
    motorized.checked = true
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
  // but not a jurisdiction with a class checked, which another's would hide and uncheck. It says the search shows, once
  // it does
  #writeUrl () {
    const url = new URL(window.location)
    const filters = this.#filters
    const jurisdiction = filters.jurisdiction || 'US'
    const classChecked = this.classificationTarget.querySelector('input:checked')
    this.#applyParams(url, {
      ...filters,
      market: filters.market === this.defaultMarketValue ? '' : filters.market,
      jurisdiction: jurisdiction === this.defaultJurisdictionValue && !classChecked ? '' : jurisdiction,
      search: this.element.hidden ? '' : '1'
    })
    replaceUrl(url)
    this.refreshClear()
  }

  // A clear link's href: this page less its filters but the market, how it narrows, and e-bike classification, which it
  // renders afresh at their defaults. Set again as it's clicked, since the panel's own state and the picks reach the URL
  // without a filter changing
  refreshClear () {
    const url = new URL(window.location)
    for (const name of Object.keys(this.#filters).filter((name) => ![...MARKET_FIELDS, 'jurisdiction'].includes(name))) url.searchParams.delete(name)
    // propulsion shares classes' param
    if (this.#classes.length) url.searchParams.set('electric', this.#classes.join(','))
    for (const link of this.clearTargets) link.href = readable(url)
  }

  get #classes () {
    return [...this.classificationTarget.querySelectorAll('input:checked')].map(({ value }) => value)
  }

  #applyParams (url, filters = this.#filters) {
    const params = {
      ...filters,
      sort: this.sortValue === 'price' ? 'price' : '',
      year_dir: this.yearDirValue === 'asc' ? 'asc' : '',
      price_dir: this.priceDirValue === 'asc' ? 'asc' : ''
    }
    for (const [key, value] of Object.entries(params)) value ? url.searchParams.set(key, value) : url.searchParams.delete(key)
  }

  // a clear keeps the market, how it narrows, and e-bike classification, so they alone - with the e-Vehicle (motorized) they check -
  // leave nothing to clear
  #refreshSummary () {
    const { market, market_scope: marketScope, jurisdiction, electric, ...filters } = this.#filters
    const kept = this.#classes.length ? [...this.#classes, '1'] : []
    const filtered = Object.values(filters).some(Boolean) || electric.split(',').some((value) => value && !kept.includes(value))
    for (const link of this.clearTargets) link.hidden = !filtered
    this.summaryTarget.replaceChildren(...this.#summary.map(([label, value]) => {
      const item = document.createElement('li')
      const name = document.createElement('strong')
      name.textContent = `${label}: `
      item.append(name, value)
      return item
    }))
  }

  // The market's fields are left out, as every visit starts with them
  get #summary () {
    return this.fieldTargets.filter((field) => !MARKET_FIELDS.some((name) => field.querySelector(`input[name="${name}"]`)))
      .map((field) => [field.dataset.filterLabel, this.#describe(field)])
      .filter(([, value]) => value)
  }

  #describe (field) {
    const inputs = [...field.querySelectorAll('input[name]')]
    // what the catalog names, which leaves out a value while it loads
    if (field.matches('.hw-combobox')) {
      return inputs[0].value.split(',').filter(Boolean)
        .flatMap((value) => field.querySelector(`[role="option"][data-value="${CSS.escape(value)}"]`)?.dataset.autocompletableAs ?? [])
        .join(', ')
    }
    // the classes alone, without the jurisdiction they're of
    const boxes = inputs.filter(({ type }) => type === 'checkbox')
    if (boxes.length) return boxes.filter(({ checked }) => checked).map(({ labels }) => labels[0].textContent.trim()).join(', ')
    // a year ungrouped, unlike an amount
    const prefix = field.dataset.filterPrefix
    const [min, max] = inputs.map(({ value }) => value && (prefix ? `${prefix}${Number(value).toLocaleString('en-US')}` : value))
    if (min && max) return `${min}–${max}`
    return min ? `from ${min}` : max && `up to ${max}`
  }

  // A set of checkboxes is one comma-joined value, blank when none is checked, and radios the checked one's
  get #filters () {
    const inputs = this.fieldTargets.flatMap((field) => [...field.querySelectorAll('input[name]')])
    return Object.fromEntries([...new Set(inputs.map(({ name }) => name))].map((name) => [name, inputs
      .filter((input) => input.name === name && (!['checkbox', 'radio'].includes(input.type) || input.checked))
      .map(({ value }) => value).join(',')]))
  }

  #showSort () {
    for (const field of ['year', 'price']) {
      const arrow = this[`${field}ArrowTarget`]
      arrow.textContent = this.#arrow(this[`${field}DirValue`])
      arrow.closest('button').setAttribute('aria-pressed', field === this.sortValue)
    }
  }

  #arrow (dir) {
    return dir === 'asc' ? '↑' : '↓'
  }
}
