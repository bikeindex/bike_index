import { Controller } from '@hotwired/stimulus'

/* global localStorage  */

// Connects to data-controller='search--targeting-fields--component'
export default class extends Controller {
  static targets = ['distance', 'location', 'fieldResetsCount', 'nonCount', 'stolenCount', 'proximityCount']
  static values = { apiCountUrl: String, interpretedParams: Object }

  connect () {
    const interpretedParams = this.interpretedParamsValue

    this.setSearchProximity(interpretedParams)
  }

  setSearchProximity (interpretedParams) {
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
        console.log("ignored location")
        location = 'you'
      }
      // Then set the location from whatever we got
      this.locationTarget.value = location
    }

    // Then set up the counts
    this.setStolennessCounts(Object.assign({}, interpretedParams, { location }))
  }

  ignoredLocation (location) {
    if (!location) { return true };

    return (location.match(/anywhere/i) || location.match(/you/i))
  }

  // TODO: Should this just be getting the values from the form?
  setStolennessCounts (interpretedParams) {
    if (this.doNotFetchCounts(interpretedParams)) return

    const searchParams = new URLSearchParams(interpretedParams)

    fetch(`${this.apiCountUrlValue}?${searchParams.toString()}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    })
      .then(response => response.json())
      .then(data => { this.insertTabCounts(data) })

    // TODO: connect to targets via fieldResetsCount to reset counts if they change value
  }

  insertTabCounts (counts) {
    // console.log(counts)
    for (const stolenness of Object.keys(counts)) {
      this[`${stolenness}CountTarget`].textContent = this.displayedCountNumber(counts[stolenness])
    }
  }

  displayedCountNumber (number) {
    if (number > 999) {
      if (number > 99999) {
        number = '100k+'
      } else if (number > 9999) {
        number = '10k+'
      } else {
        number = `${String(number).charAt(0)}k+`
      }
    }
    return `(${number})`
  }


  doNotFetchCounts (interpretedParams) {

    console.log(interpretedParams)
    // if (interpretedParams.query)
    return false
  }
}
