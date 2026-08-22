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

    const opening = this.element.classList.contains('tw:hidden')
    collapse(opening ? 'show' : 'hide', this.element)
    this.dispatch('opened', { detail: { opening }, prefix: 'admin--search-statuses' })
  }

  // Keeps the trigger's is-active styling in step with the panel. The legacy JS toggled an
  // .active class for this, which the button had to style around because the server owned
  // data-active; with the state here, data-active is what it already reads.
  syncTrigger ({ detail: { opening } }) {
    this.element.dataset.active = opening
  }
}
