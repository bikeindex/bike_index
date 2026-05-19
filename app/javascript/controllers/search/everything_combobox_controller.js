import { Controller } from '@hotwired/stimulus'

/* global MutationObserver, URL */

// Connects to data-controller='search--everything-combobox'
//
// Wraps the hotwire_combobox that powers the search query items field. The
// combobox keeps a single comma-joined hidden field; this controller mirrors
// that value into query_items[] fields (what the server expects), keeps
// window.searchBarCategories in sync so autocomplete results stay relevant,
// and submits the form on enter.
export default class extends Controller {
  static targets = ['combobox', 'nonjsfields']

  connect () {
    // Remove the plain query field shown to users without JS
    this.nonjsfieldsTargets.forEach(el => el.remove())

    this.fieldElement = this.element.querySelector('.hw-combobox')
    this.hiddenField = this.element.querySelector('input[data-hw-combobox-target="hiddenField"]')

    // Hold the query_items[] fields that actually get submitted
    this.queryItems = document.createElement('div')
    this.queryItems.hidden = true
    this.element.appendChild(this.queryItems)

    // Reveal the combobox now that JS is handling it
    if (this.hasComboboxTarget) this.comboboxTarget.classList.remove('tw:hidden')

    this.syncQueryItems()

    this.element.addEventListener('hw-combobox:selection', this.afterChange)
    this.element.addEventListener('hw-combobox:removal', this.afterChange)

    this.inputElement = this.element.querySelector('.hw-combobox__input')
    // Capture phase so we can act before the combobox handles enter itself
    this.inputElement?.addEventListener('keydown', this.onEnterKey, true)

    // The combobox hides its chips before Turbo caches the page; the search
    // form lives outside the results frame and never reconnects to restore
    // them, so keep the chips visible ourselves.
    this.showChips()
    this.chipObserver = new MutationObserver(this.showChips)
    this.chipObserver.observe(this.element, { attributeFilter: ['hidden'], subtree: true })
  }

  disconnect () {
    this.element.removeEventListener('hw-combobox:selection', this.afterChange)
    this.element.removeEventListener('hw-combobox:removal', this.afterChange)
    this.inputElement?.removeEventListener('keydown', this.onEnterKey, true)
    this.chipObserver?.disconnect()
  }

  showChips = () => {
    this.element.querySelectorAll('[data-hw-combobox-chip][hidden]').forEach(chip => { chip.hidden = false })
  }

  // The selection event fires before the combobox writes the new value to its
  // hidden field, so defer a tick to read the up-to-date value.
  afterChange = () => {
    Promise.resolve().then(() => {
      this.syncQueryItems()
      window.kindControllerUpdateAfterComboboxChange?.()
      // Keep focus in the field after a mouse selection so enter still submits
      this.inputElement?.focus()
    })
  }

  syncQueryItems () {
    const values = (this.hiddenField?.value || '').split(',').filter(value => value.length)

    this.queryItems.replaceChildren(...values.map(value => {
      const input = document.createElement('input')
      input.type = 'hidden'
      input.name = 'query_items[]'
      input.value = value
      return input
    }))

    this.setCategories(values)
  }

  // Don't autocomplete manufacturers if a manufacturer is already selected, etc.
  setCategories (values) {
    const queriedCategories = values
      .filter(value => /^(v|m)_/.test(value))
      .map(value => value.split('_')[0])

    let categories = ''
    if (queriedCategories.length > 0) {
      categories = 'colors'

      if (!queriedCategories.includes('v')) categories += ',cycle_type'
      if (!queriedCategories.includes('m')) categories += ',frame_mnfg,cmp_mnfg'
      if (!queriedCategories.includes('p')) categories += ',propulsion'
    }

    window.searchBarCategories = categories
    this.updateAsyncSrc(categories)
  }

  // Push the categories filter onto the combobox's async autocomplete URL
  updateAsyncSrc (categories) {
    if (!this.fieldElement) return

    const attribute = 'data-hw-combobox-async-src-value'
    const url = new URL(this.fieldElement.getAttribute(attribute), window.location.origin)

    if (categories) {
      url.searchParams.set('categories', categories)
    } else {
      url.searchParams.delete('categories')
    }

    this.fieldElement.setAttribute(attribute, url.pathname + url.search)
  }

  onEnterKey = (event) => {
    if (event.key !== 'Enter') return

    // Enter on an empty input submits the search
    if (this.inputElement.value.trim() === '') {
      event.preventDefault()
      this.element.closest('form')?.requestSubmit()
      return
    }

    // With a typed query, prefer a matching autocomplete option over free text.
    // If nothing matches, fall through and let the combobox add it as free text.
    const option = this.matchingOption()
    if (option) {
      event.preventDefault()
      event.stopImmediatePropagation()
      option.click()
    }
  }

  // The active option if the user navigated to one, otherwise the first match
  matchingOption () {
    const query = this.inputElement.value.trim().toLowerCase()
    const options = Array.from(this.element.querySelectorAll('.hw-combobox__option'))
      .filter(option => !option.hidden && option.offsetParent !== null)
      // The listbox can still show stale results from a previous query, so
      // only consider options whose text actually contains what was typed
      .filter(option => (option.getAttribute('data-autocompletable-as') || '').toLowerCase().includes(query))

    return options.find(option => option.getAttribute('aria-selected') === 'true') || options[0]
  }
}
