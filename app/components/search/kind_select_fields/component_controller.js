import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global localStorage  */

// Connects to data-controller='search--kind-select-fields--component'
export default class extends Controller {
  static targets = ['distance', 'location', 'locationWrap']
  static values = { apiCountUrl: String, isMarketplace: Boolean, locationStoreKey: String, optionKinds: String }

  connect () {
    this.setSearchProximity()
    this.updateCountsToSubmit()
    this.updateForSaleLink.bind(this)
    this.form.addEventListener('change', this.updateForSaleLink.bind(this))
  }

  disconnect () {
    this.resetKindCounts() // also removes the bindings
    this.form.removeEventListener('change', this.updateForSaleLink.bind(this))
    // Remove reset count function from window
    window.resetKindCounts = null
  }

  get form () {
    return (this.element.closest('form'))
  }

  // Can we use get here?
  get searchQuery () {
    const formData = new FormData(this.form)
    return new URLSearchParams(formData).toString()
  }

  updateForSaleLink () {
    const link = document.getElementById('kindSelectForSaleLink')

    if (link) {
      link.href = `${link.getAttribute('data-basepath')}?${this.searchQuery}`
    }
  }

  updateCountsToSubmit () {
    if (!this.form) return

    this.form.addEventListener('turbo:submit-end', this.setKindCounts.bind(this))

    // if in component preview (lookbook), run kind counts on load
    if (window.inComponentPreview) { this.setKindCounts() }
  }

  updateLocationVisibility () {
    const selectedValue = this.element.querySelector(`input[name="${this.optionKindsValue}"]:checked`)?.value

    if (selectedValue === 'proximity' || selectedValue === 'for_sale_proximity') {
      collapse('show', this.locationWrapTarget)
    } else {
      collapse('hide', this.locationWrapTarget)
    }
  }

  // TODO: make this location target_search_path specific, but falls back to general location
  setSearchProximity () {
    let location = this.locationTarget.value
    // strip the location text
    location = location ? location.replace(/^\s*|\s*$/g, '') : ''

    // Store location in localStorage if it's there, otherwise -
    // Set from localStorage - so we don't override if it's already set
    if (location && location.length > 0) {
      // Don't save location if user entered 'Anywhere'
      if (!location.match(/anywhere/i)) {
        localStorage.setItem('location', location)
      }
    } else {
      location = localStorage.getItem('location')
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

  // TODO: Should this just be getting the values from the form?
  setKindCounts () {
    const queryString = this.searchQuery
    if (this.doNotFetchCounts(queryString)) {
      return this.resetKindCounts()
    }

    fetch(`${this.apiCountUrlValue}?${queryString}`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' }
    })
      .then(response => response.json())
      .then(data => { this.insertTabCounts(data) })

    this.setResetFieldListeners()
  }

  setResetFieldListeners () {
    this.resetFields = this.form.querySelectorAll('.fieldResetsCounts')

    this.resetFields?.forEach(field => {
      // Save the bound function reference so we can remove it later
      field._boundResetFunction = this.resetKindCounts.bind(this)
      field.addEventListener('change', field._boundResetFunction)
    })
    // Add reset function to window so it can be called by select2 callback
    window.resetKindCounts = this.resetKindCounts.bind(this)
  }

  resetKindCounts () {
    console.log('resetting counts')
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
