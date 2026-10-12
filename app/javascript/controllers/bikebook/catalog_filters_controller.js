import { Controller } from '@hotwired/stimulus'
import { replaceUrl } from 'bikebook/replace_url'

/* global CSS */

// Threads the filter panel's values into the vehicle combobox's async src and mirrors them
// into the page URL, which the page renders the controls from (ui--collapse owns ?filters)
export default class extends Controller {
  static targets = ['vehicleCombobox', 'yearArrow', 'priceArrow', 'summary', 'field', 'jurisdiction']
  static values = {
    yearDir: { type: String, default: 'desc' },
    priceDir: { type: String, default: 'desc' }
  }

  // Rewritten on connect too, as rendering drops stale values. Not from the loading placeholder,
  // whose empty fields would clear the URL's filters
  connect () {
    this.yearArrowTarget.textContent = this.#arrow(this.yearDirValue)
    this.priceArrowTarget.textContent = this.#arrow(this.priceDirValue)
    this.showJurisdiction()
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

  // A state without its own classes uses the US ones. Runs before its fieldset's apply, which a change
  // bubbles on to, and a hidden class doesn't stay checked
  showJurisdiction () {
    const groups = [...this.jurisdictionTarget.closest('fieldset').querySelectorAll('[data-jurisdiction]')]
    const shown = groups.find(({ dataset }) => dataset.jurisdiction === this.jurisdictionTarget.value) ?? groups[0]
    for (const group of groups) {
      const hidden = group !== shown
      group.classList.toggle('tw:hidden', hidden)
      if (hidden) for (const input of group.querySelectorAll('input')) input.checked = false
    }
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
      jurisdiction: this.jurisdictionTarget.value,
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
    if (inputs[0].type === 'checkbox') {
      const checked = inputs.filter(({ checked }) => checked).map(({ labels }) => labels[0].textContent.trim()).join(', ')
      const jurisdiction = field.querySelector('select')?.selectedOptions[0]
      return checked && jurisdiction?.value ? `${checked} (${jurisdiction.text})` : checked
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
