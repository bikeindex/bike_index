import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='registrations--show--action-panels'
// Accordion for the org-admin action-card panels: at most one panel is open, and
// the open panel's name is kept in the `panel` URL param so a reload (or shared
// link) reopens it. Each panel declares the names it answers to via
// data-panel-name (space-separated); each trigger passes one name through
// data-panel-name. A panel with several names opens in a variant per name (e.g.
// the parking form answers to both "parking" and "impound"). The open value names
// the panel to start on when the URL doesn't.
export default class extends Controller {
  static targets = ['panel', 'trigger']
  static values = { open: String }

  connect () {
    const name = new URLSearchParams(window.location.search).get('panel') || this.openValue
    // Defer so panel controllers finish connecting and their `shown` listeners
    // are registered first (e.g. parking-notification's geolocation on open)
    if (name) window.requestAnimationFrame(() => this.open(name, 0))
  }

  toggle (event) {
    event.preventDefault()
    const { panelName } = event.currentTarget.dataset
    this.open(this.openName === panelName ? null : panelName)
  }

  open (name, duration) {
    this.panelTargets.forEach((panel) => {
      const show = panel.dataset.panelName.split(' ').includes(name)
      collapse(show ? 'show' : 'hide', panel, duration)
      // Let the panel react to which name opened it (e.g. impound vs notification)
      if (show) this.dispatch('shown', { target: panel, detail: { name } })
    })
    this.triggerTargets.forEach((trigger) => {
      const active = String(trigger.dataset.panelName === name)
      // aria-expanded for disclosure semantics, data-active drives UI::Button's styling
      trigger.setAttribute('aria-expanded', active)
      trigger.dataset.active = active
    })
    this.openName = name
    this.persist(name)
  }

  // Reflect the open panel in the URL, preserving history state (Turbo) and
  // without adding a history entry
  persist (name) {
    const url = new URL(window.location)
    if (name) url.searchParams.set('panel', name)
    else url.searchParams.delete('panel')
    window.history.replaceState(window.history.state, '', url)
  }
}
