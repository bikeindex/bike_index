import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// en-CA writes the local date as YYYY-MM-DD
const startOfToday = () => `${new Date().toLocaleDateString('en-CA')}T00:00`

// Connects to data-controller='org--field-expander'
// A time target is cleared when collapsed, so the form doesn't submit a hidden value
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
