import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='admin--search-statuses'
//
// Replaces initBikeStatusesSearch from the vendored admin bundle. The trigger sits in the
// index's nav row and the panel inside the search form -- different branches of
// Admin::IndexSkeleton, so they talk over a window event rather than an outlet.
//
// Registered on both: the trigger dispatches, the panel listens.
export default class extends Controller {
  static values = { locked: Boolean }

  dispatchToggle () {
    window.dispatchEvent(new CustomEvent('admin--search-statuses:toggle'))
  }

  // Once a status has been changed the panel stops closing -- collapsing it would hide
  // which statuses the results are actually for
  lock () {
    this.lockedValue = true
  }

  toggle () {
    if (this.lockedValue) return

    collapse(this.element.classList.contains('tw:hidden') ? 'show' : 'hide', this.element)
  }
}
