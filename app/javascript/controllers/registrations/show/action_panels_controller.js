import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='registrations--show--action-panels'
// Accordion for the org-admin action-card panels: at most one panel is open, and
// the open panel's name is kept in the `panel` URL param so a reload (or shared
// link) reopens it. Each panel declares its name via data-panel-name; each
// trigger passes the name through the `name` action param.
export default class extends Controller {
  static targets = ['panel']

  connect () {
    const name = new URLSearchParams(window.location.search).get('panel')
    if (name) this.open(name, 0)
  }

  toggle (event) {
    event.preventDefault()
    const name = event.params.name
    this.open(this.openName === name ? null : name)
  }

  open (name, duration = 200) {
    this.panelTargets.forEach((panel) => {
      const show = panel.dataset.panelName === name
      collapse(show ? 'show' : 'hide', panel, duration)
      if (show) this.dispatch('shown', { target: panel })
    })
    this.openName = name
    this.trackOpen(name)
  }

  // Reflect the open panel in the URL without adding a history entry
  trackOpen (name) {
    const url = new URL(window.location)
    if (name) url.searchParams.set('panel', name)
    else url.searchParams.delete('panel')
    window.history.replaceState({}, '', url)
  }
}
