import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// The browser's local date, which toISOString would otherwise give in UTC
const startOfToday = () => `${new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 10)}T00:00`

// Connects to data-controller='org--field-expander'
// Swaps the collapsed targets for the expanded ones. A time target starts at today when
// expanded, and is cleared when collapsed so the form doesn't submit a hidden value
export default class extends Controller {
  static targets = ['collapsed', 'expanded', 'time']

  expand () {
    collapse('hide', this.collapsedTargets)
    collapse('show', this.expandedTargets)
    this.timeTargets.forEach((input) => { input.value = startOfToday() })
  }

  collapse () {
    collapse('hide', this.expandedTargets)
    collapse('show', this.collapsedTargets)
    this.timeTargets.forEach((input) => { input.value = '' })
  }
}
