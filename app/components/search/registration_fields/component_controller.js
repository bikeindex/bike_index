import { Controller } from '@hotwired/stimulus'

/* global localStorage  */

// Connects to data-controller='search--registration-fields--component'
export default class extends Controller {
  static targets = ['distance', 'location', 'locationWrap', 'fieldResetsCounts', 'nonCount', 'stolenCount', 'proximityCount']
  static values = { apiCountUrl: String, interpretedParams: Object }

  connect () {
    const interpretedParams = this.interpretedParamsValue

    this.updateLocationVisibility()
    this.setSearchProximity(interpretedParams)
  }

  updateLocationVisibility () {
    const selectedValue = this.element.querySelector('input[name="stolenness"]:checked')?.value
    if (selectedValue === 'proximity') {
      this.uncollapseElement(this.locationWrapTarget)
    } else {
      this.collapseElement(this.locationWrapTarget)
    }
  }

  // TODO: generalizable collapse component,
  // add will-change: height;
  // form fields padding is weird
  uncollapseElement (element) {
    // Remove height constraints
    element.classList.remove('tw:h-0', 'tw:overflow-hidden', 'tw:collapse')

    // Get the natural height of the element
    const height = element.scrollHeight

    // Set the element's height to its natural height to trigger transition
    element.style.height = height + 'px'

    // After transition is complete, remove explicit height to allow for responsive changes
    setTimeout(() => {
      element.style.height = ''
    }, 300) // Match the duration with the CSS transition duration
  }

  collapseElement (element) {
    // First set an explicit height to enable the transition
    element.style.height = element.scrollHeight + 'px'
    // Add classes that will collapse it
    element.classList.add('tw:overflow-hidden')

    // Transition to height 0
    element.style.height = '0px'

    // After transition completes, add 'invisible' class for accessibility
    setTimeout(() => {
      element.classList.add('tw:h-0', 'tw:collapse')
    }, 300) // Match the duration with the CSS transition duration
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
    // console.log(this.fieldResetsCountsTargets)
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

  // TODO: Make this no fetch counts for times where there are no query items
  doNotFetchCounts (interpretedParams) {
    // if (this.ignoredLocation(interpretedParams.location)
    // console.log(interpretedParams)
    // if (interpretedParams.query)
    return false
  }
}
