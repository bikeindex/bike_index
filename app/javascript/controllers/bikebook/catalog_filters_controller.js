import { Controller } from '@hotwired/stimulus'
import { replaceUrl } from 'bikebook/replace_url'

/* global CSS */

// Threads the filter panel's values into the vehicle combobox's async src and mirrors them
// into the page URL, which the page renders the controls from (ui--collapse owns ?filters)
export default class extends Controller {
  static targets = ['vehicleCombobox', 'yearArrow', 'priceArrow', 'summary', 'field']
  static values = {
    yearDir: { type: String, default: 'desc' },
    priceDir: { type: String, default: 'desc' }
  }

  // Rewritten on connect too: a GET form submit escapes the commas, and rendering drops stale values.
  // Not from the loading placeholder, whose empty fields would clear the URL's filters
  connect () {
    this.yearArrowTarget.textContent = this.#arrow(this.yearDirValue)
    this.priceArrowTarget.textContent = this.#arrow(this.priceDirValue)
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
    this.#syncCombobox()
    this.#refreshSummary()
    this.#writeUrl()
  }

  // A multiselect fires hw-combobox:selection before it writes the hidden field,
  // so defer a tick to read the picked value.
  applySelection () {
    setTimeout(() => this.apply(), 0)
  }

  #syncCombobox () {
    const fieldset = this.vehicleComboboxTarget.querySelector('.hw-combobox')
    const url = new URL(fieldset.dataset.hwComboboxAsyncSrcValue, window.location.origin)
    this.#applyParams(url)
    fieldset.dataset.hwComboboxAsyncSrcValue = url.pathname + url.search
    fieldset.querySelector('.hw-combobox__input').dispatchEvent(new Event('input', { bubbles: true }))
  }

  #writeUrl () {
    const url = new URL(window.location)
    this.#applyParams(url)
    replaceUrl(url)
  }

  #applyParams (url) {
    const params = {
      ...this.#filters,
      year_dir: this.yearDirValue === 'asc' ? 'asc' : '',
      price_dir: this.priceDirValue === 'asc' ? 'asc' : ''
    }
    for (const [key, value] of Object.entries(params)) value ? url.searchParams.set(key, value) : url.searchParams.delete(key)
  }

  #refreshSummary () {
    this.summaryTarget.replaceChildren(...this.#summary.map(([label, value]) => {
      const item = document.createElement('li')
      const name = document.createElement('strong')
      name.textContent = `${label}: `
      item.append(name, value)
      return item
    }))
  }

  get #summary () {
    return this.fieldTargets.map((field) => [field.dataset.filterLabel, this.#describe(field)])
      .filter(([, value]) => value)
  }

  #describe (field) {
    const inputs = [...field.querySelectorAll('input[name]')]
    if (field.matches('.hw-combobox')) {
      return inputs[0].value.split(',').filter(Boolean)
        .map((value) => field.querySelector(`[role="option"][data-value="${CSS.escape(value)}"]`)?.dataset.autocompletableAs ?? value)
        .join(', ')
    }
    const [min, max] = inputs.map(({ value }) => value && `${field.dataset.filterPrefix}${value}`)
    if (min && max) return `${min}–${max}`
    return min ? `from ${min}` : max && `up to ${max}`
  }

  get #filters () {
    return Object.fromEntries(this.fieldTargets.flatMap((field) => [...field.querySelectorAll('input[name]')])
      .map(({ name, value }) => [name, value]))
  }

  #arrow (dir) {
    return dir === 'asc' ? '↑' : '↓'
  }
}
