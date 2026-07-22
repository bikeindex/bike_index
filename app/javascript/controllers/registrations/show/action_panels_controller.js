import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='registrations--show--action-panels'
// Accordion for the org-admin action-card panels: at most one panel is open, and
// the open panel's name is kept in the `panel` URL param so a reload (or shared
// link) reopens it. Each panel declares its name via data-panel-name; each
// trigger passes the name through the `name` action param.
export default class extends Controller {
  static targets = ['panel', 'trigger']

  connect () {
    const name = new URLSearchParams(window.location.search).get('panel')
    if (name) this.open(name, 0)
  }

  toggle (event) {
    event.preventDefault()
    const name = event.currentTarget.dataset.panelName
    this.open(this.openName === name ? null : name)
  }

  open (name, duration = 200) {
    this.panelTargets.forEach((panel) => {
      collapse(panel.dataset.panelName === name ? 'show' : 'hide', panel, duration)
    })
    // Mark the open panel's trigger: aria-expanded for disclosure semantics,
    // aria-pressed drives its active (solid) styling
    this.triggerTargets.forEach((trigger) => {
      const active = String(trigger.dataset.panelName === name)
      trigger.setAttribute('aria-expanded', active)
      trigger.setAttribute('aria-pressed', active)
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
