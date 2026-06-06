import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global localStorage  */

// Connects to data-controller='search--kind-select-fields'
export default class extends Controller {
  static targets = ['distance', 'location', 'locationWrap']
  static values = { apiCountUrl: String, optionKinds: String, storageKeyLocation: String, storageKeyDistance: String }

  connect () {
    this.setLocalstorageKeys()
    this.setSearchProximity()
    this.updateForSaleLink()
    this.form?.addEventListener('change', this.updateForSaleLink.bind(this))
    this.form?.addEventListener('turbo:submit-end', this.performSubmitActions.bind(this))
    // Plain filter comboboxes (eg primary_activity) don't fire a native change
    // event, so reset the counts when their selection changes
    this.form?.addEventListener('hw-combobox:selection', this.onComboboxSelection)
    this.form?.addEventListener('hw-combobox:removal', this.onComboboxSelection)

    // Add function to window so it can be called by select2 callback
    window.kindControllerUpdateAfterComboboxChange = this.updateAfterComboboxChange.bind(this)
    // Load counts on connect. The eager turbo-frame flow no longer submits the
    // form on initial render (which used to fire setKindCounts via
    // turbo:submit-end), so fetch them here. Also covers component preview.
    this.setKindCounts()
  }

  disconnect () {
    this.resetKindCounts() // also removes the bindings
    this.form?.removeEventListener('change', this.updateForSaleLink.bind(this))
    this.form?.removeEventListener('turbo:submit-end', this.performSubmitActions.bind(this))
    // Remove reset count function from window
    window.kindControllerUpdateAfterComboboxChange = null
    this.form?.removeEventListener('hw-combobox:selection', this.onComboboxSelection)
    this.form?.removeEventListener('hw-combobox:removal', this.onComboboxSelection)
  }

  // The everything-combobox manages its own reset after mirroring its values
  // into query_items[], so only the plain filter comboboxes route through here
  onComboboxSelection = (event) => {
    if (event.target.closest('[data-controller~="search--everything-combobox"]')) { return }

    this.updateAfterComboboxChange()
  }

  get form () {
    return (this.element.closest('form'))
  }

  get searchQuery () {
    if (!this.form) { return '' }
    const formData = new FormData(this.form)
    return new URLSearchParams(formData).toString()
  }

  setLocalstorageKeys () {
    if (window.inComponentPreview) {
      this.storageKeyLocation = 'preview-searchLocation'
      this.storageKeyDistance = 'preview-searchDistance'
    } else {
      this.storageKeyLocation = 'searchLocation'
      this.storageKeyDistance = 'searchDistance'
    }
  }

  updateForSaleLink () {
    const link = document.getElementById('kindSelectForSaleLink')

    if (link) {
      link.href = `${link.getAttribute('data-basepath')}?${this.searchQuery}`
    }
  }

  performSubmitActions () {
    // store search proximity on form submit
    this.setSearchProximity()
    // Update kind counts
    this.setKindCounts()
  }

  updateLocationVisibility () {
    const selectedValue = this.element.querySelector(`input[name="${this.optionKindsValue}"]:checked`)?.value

    if (['proximity', 'for_sale_proximity'].includes(selectedValue)) {
      collapse('show', this.locationWrapTarget)
    } else {
      collapse('hide', this.locationWrapTarget)
    }
  }

  setSearchProximity () {
    let location = this.locationTarget.value
    // strip the location text
    location = location ? location.replace(/^\s*|\s*$/g, '') : ''

    // Store location in localStorage if it's there, otherwise -
    // Set from localStorage - so we don't override if it's already set
    if (location && location.length > 0) {
      // Don't save location if location is an ignored string
      if (!this.ignoredLocation(location)) {
        // console.log(`setting location: '${location}' (storageKeyLocation: ${this.storageKeyLocation})`)
        localStorage.setItem(this.storageKeyLocation, location)
        // save distance if location is being saved
        const distance = this.distanceTarget.value
        if (distance && distance.length > 0) {
          localStorage.setItem(this.storageKeyDistance, distance)
        }
      }
    } else {
      location = localStorage.getItem(this.storageKeyLocation)
      // console.log(`got location: '${location}' (storageKeyLocation: ${this.storageKeyLocation})`)
      // Make location 'you' if location is anywhere or blank, so user isn't stuck and unable to use location
      if (this.ignoredLocation(location)) {
        location = 'you'
      }
      // Then set the location from whatever we got
      this.locationTarget.value = location
    }
  }

  ignoredLocation (location) {
    if (!location) { return true };

    return ['anywhere', 'you'].includes(location.toLowerCase().trim())
  }

  setKindCounts () {
    const queryString = this.searchQuery
    if (this.doNotFetchCounts(queryString)) {
      return this.resetKindCounts()
    }

    // Skip if the rendered counts already reflect this query - eg Turbo
    // reconnecting the controller against a cached snapshot whose counts are
    // already filled in. The marker lives on the element so it rides along in the
    // cached DOM; resetKindCounts clears it whenever the counts are blanked.
    if (this.element.dataset.countsQuery === queryString) {
      return this.setResetFieldListeners()
    }

    fetch(`${this.apiCountUrlValue}?${queryString}`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' }
    })
      .then(response => {
        // Counts share the per-IP API throttle; surface a 429 instead of
        // silently leaving the tab counts blank.
        if (response.status === 429) {
          window.dispatchEvent(new CustomEvent('search:rate-limited'))
          return this.resetKindCounts()
        }
        return response.json().then(data => {
          this.element.dataset.countsQuery = queryString
          this.insertTabCounts(data)
        })
      })
      .catch(() => this.resetKindCounts())

    this.setResetFieldListeners()
  }

  setResetFieldListeners () {
    if (!this.form) { return }
    this.resetFields = this.form.querySelectorAll('.fieldResetsCounts')

    this.resetFields?.forEach(field => {
      // Save the bound function reference so we can remove it later
      field._boundResetFunction = this.resetKindCounts.bind(this)
      field.addEventListener('change', field._boundResetFunction)
    })
  }

  updateAfterComboboxChange () {
    this.updateForSaleLink()
    this.resetKindCounts()
  }

  resetKindCounts () {
    // Counts are being blanked, so drop the dedupe marker - the next fetch for
    // this query must run again rather than being skipped as already-rendered.
    delete this.element.dataset.countsQuery

    // dataCountTargets looks like: ['non', 'stolen', 'proximity', 'for_sale']
    const dataCountTargets = [...this.element.querySelectorAll('[data-count-target]')]
      .map(el => el.dataset.countTarget).filter(item => item !== 'all')

    for (const kind of dataCountTargets) { this.updateCount(kind, '') }

    if (this.resetFields) {
      this.resetFields.forEach(field => {
        if (field._boundResetFunction) {
          field.removeEventListener('change', field._boundResetFunction)
          delete field._boundResetFunction
        }
      })
    }
  }

  insertTabCounts (counts) {
    for (const kind of Object.keys(counts)) {
      this.updateCount(kind, this.displayedCountNumber(counts[kind]))
    }
  }

  updateCount (kind, newValue) {
    const element = this.element.querySelector(`[data-count-target="${kind}"]`)

    if (element) {
      element.textContent = newValue
    }
  }

  displayedCountNumber (number) {
    if (number > 999) {
      if (number > 99999) {
        number = '100k+' // API limits to 10k so this never shows up
      } else if (number > 9999) {
        number = '10k+'
      } else {
        number = `${String(number).charAt(0)}k+`
      }
    }
    return `(${number})`
  }

  // TODO: Make this no fetch counts for times where there are no query items
  doNotFetchCounts (searchQuery) {
    return this.apiCountUrlValue === 'none'
  }
}
