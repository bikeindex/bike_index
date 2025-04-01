import { Controller } from '@hotwired/stimulus'

/* global localStorage  */

// Connects to data-controller='search--registration-fields--component'
export default class extends Controller {
  static targets = ['distance', 'location', 'locationWrap', 'fieldResetsCounts', 'nonCount', 'stolenCount', 'proximityCount']
  static values = { apiCountUrl: String, interpretedParams: Object }

  connect () {
    const interpretedParams = this.interpretedParamsValue

    // this.updateLocationVisibility()
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
  uncollapseElement (element, duration = 200) {
    // Remove the hidden
    element.classList.remove('tw:hidden')

    // First, ensure the hidden attributes are set
    element.classList.add('tw:scale-y-0')
    element.style.height = 0

    // Always add transition classes (moving toward a more generalizable collapse method)
    element.classList.add('tw:transition-all', `tw:duration-${duration}`)

    // Remove things that transition to hide the element
    element.classList.remove('tw:scale-y-0')

    // Set the element's height to its natural height to shrink it
    element.style.height = `${element.scrollHeight}px`

    // After transition is complete, remove explicit height (clean up afterward)
    setTimeout(() => {
      element.style.height = ''
    }, duration)
  }

  collapseElement (element, duration = 200) {
    // Always add transition classes (moving toward a more generalizable collapse method)
    element.classList.add('tw:transition-all', `tw:duration-${duration}`)
    // Add the tailwind class to shrink
    element.classList.add('tw:scale-y-0')
    // Set an explicit height to enable the transition
    element.style.height = element.scrollHeight + 'px'
    // Transition to height 0
    element.style.height = '0px'

    // After transition completes, add display: none to remove element from the flow
    setTimeout(() => {
      element.classList.add('tw:hidden')
    }, duration)
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
