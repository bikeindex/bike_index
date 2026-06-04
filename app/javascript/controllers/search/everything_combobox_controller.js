import { Controller } from '@hotwired/stimulus'

/* global MutationObserver, URL, clearTimeout, setTimeout */

// Connects to data-controller='search--everything-combobox'
//
// Wraps the hotwire_combobox that powers the search query items field. The
// combobox keeps a single comma-joined hidden field; this controller mirrors
// that value into query_items[] fields (what the server expects), keeps
// window.searchBarCategories in sync so autocomplete results stay relevant,
// submits the form on enter, and keeps the dropdown from overlaying the form.
export default class extends Controller {
  static targets = ['combobox', 'nonjsfields', 'queryItems']

  connect () {
    // Remove the plain query field shown to users without JS
    this.nonjsfieldsTargets.forEach(el => el.remove())

    this.fieldElement = this.element.querySelector('.hw-combobox')
    this.hiddenField = this.element.querySelector('input[data-hw-combobox-target="hiddenField"]')

    // Holds the query_items[] fields that actually get submitted. Reuse the
    // existing container if there is one - a Turbo-cached snapshot already
    // carries it, so creating a new one would orphan its stale inputs.
    if (this.hasQueryItemsTarget) {
      this.queryItems = this.queryItemsTarget
    } else {
      this.queryItems = document.createElement('div')
      this.queryItems.hidden = true
      this.queryItems.setAttribute('data-search--everything-combobox-target', 'queryItems')
      this.element.appendChild(this.queryItems)
    }

    // Reveal the combobox now that JS is handling it
    if (this.hasComboboxTarget) this.comboboxTarget.classList.remove('tw:hidden')

    this.syncQueryItems()

    this.element.addEventListener('hw-combobox:selection', this.afterChange)
    this.element.addEventListener('hw-combobox:removal', this.afterChange)

    this.inputElement = this.element.querySelector('.hw-combobox__input')
    // Capture phase so we can act before the combobox handles enter itself
    this.inputElement?.addEventListener('keydown', this.onEnterKey, true)

    // Track whether a user gesture is in progress, so we can tell a deliberate
    // open from the async dropdown reopen the combobox does after a selection
    this.element.addEventListener('click', this.markUserEvent, true)
    this.element.addEventListener('keydown', this.markUserEvent, true)

    // One observer for two jobs:
    // - keep chips visible (the combobox hides them before Turbo caches the
    //   page, but the search form never reconnects to restore them)
    // - close the dropdown when it reopens itself after a selection, so it
    //   doesn't overlay the rest of the form
    this.showChips()
    this.observer = new MutationObserver(this.handleMutations)
    this.observer.observe(this.element, {
      attributeFilter: ['hidden', 'data-hw-combobox-expanded-value'],
      subtree: true
    })

    // Let the search form know its query fields are ready: the non-JS `query`
    // field is gone and query_items[] is populated. Its empty-results
    // auto-submit waits for this so a restored page submits query_items[]
    // instead of the stale `query` field (which made the URL drop the items).
    document.dispatchEvent(new CustomEvent('search--combobox:connected'))
  }

  disconnect () {
    this.element.removeEventListener('hw-combobox:selection', this.afterChange)
    this.element.removeEventListener('hw-combobox:removal', this.afterChange)
    this.inputElement?.removeEventListener('keydown', this.onEnterKey, true)
    this.element.removeEventListener('click', this.markUserEvent, true)
    this.element.removeEventListener('keydown', this.markUserEvent, true)
    this.observer?.disconnect()
    clearTimeout(this.userEventTimer)
  }

  handleMutations = (records) => {
    this.showChips()
    records.forEach(record => {
      if (record.attributeName === 'data-hw-combobox-expanded-value') {
        this.suppressAutoReopen(record.target)
      }
    })
  }

  showChips = () => {
    this.element.querySelectorAll('[data-hw-combobox-chip][hidden]').forEach(chip => { chip.hidden = false })
  }

  markUserEvent = () => {
    this.inUserEvent = true
    clearTimeout(this.userEventTimer)
    this.userEventTimer = setTimeout(() => { this.inUserEvent = false }, 0)
  }

  // The async multiselect reopens the dropdown after a selection; if it opened
  // without a user gesture, close it so it doesn't cover the rest of the form.
  suppressAutoReopen (combobox) {
    if (!this.inUserEvent && combobox.getAttribute('data-hw-combobox-expanded-value') === 'true') {
      combobox.setAttribute('data-hw-combobox-expanded-value', 'false')
    }
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

    if (categories === this.appliedCategories) return
    this.appliedCategories = categories

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
