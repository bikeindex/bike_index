import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global localStorage  */

// Connects to data-controller='search--kind-select-fields--component'
export default class extends Controller {
  static targets = ['distance', 'location', 'locationWrap']
  static values = { apiCountUrl: String, isMarketplace: Boolean, locationStoreKey: String }

  connect () {
    this.setSearchProximity()
    this.updateCountsToSubmit()
  }

  disconnect () {
    this.resetStolennessCounts() // also removes the bindings
  }

  get form () {
    return (this.element.closest('form'))
  }

  // Can we use get here?
  get searchQuery () {
    const formData = new FormData(this.form)
    return new URLSearchParams(formData).toString()
  }

  updateCountsToSubmit () {
    if (!this.form) return

    this.form.addEventListener('turbo:submit-end', this.setStolennessCounts.bind(this))

    // if in component preview (lookbook), run stolenness counts on load
    if (window.inComponentPreview) { this.setStolennessCounts() }
  }

  updateLocationVisibility () {
    const selectedValue = this.element.querySelector('input[name="stolenness"]:checked')?.value

    if (selectedValue === 'proximity' || selectedValue === 'for_sale') {
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
  setStolennessCounts () {
    const queryString = this.searchQuery
    if (this.doNotFetchCounts(queryString)) {
      return this.resetStolennessCounts()
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
      field._boundResetFunction = this.resetStolennessCounts.bind(this)
      field.addEventListener('change', field._boundResetFunction)
    })
  }

  resetStolennessCounts () {
    console.log('resetting counts')
    // NOTE: countKeys will need to be updated if response changes
    const countKeys = ['non', 'stolen', 'proximity']
    // for (const stolenness of countKeys) { this[`${stolenness}CountTarget`].textContent = '' }
    for (const stolenness of countKeys) { this.updateCount(stolenness, '') }

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
    for (const stolenness of Object.keys(counts)) {
      console.log(stolenness)
      this.updateCount(stolenness, this.displayedCountNumber(counts[stolenness]))
    }
  }

  updateCount(stolenness, newValue) {
    const element = this.element.querySelector(`[data-count-target="${stolenness}"]`)

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
    // if (this.apiCountUrl === "none") { return true }

    // if (this.ignoredLocation(interpretedParams.location)
    // console.log(interpretedParams)
    // if (interpretedParams.query)
    return false
  }
}
