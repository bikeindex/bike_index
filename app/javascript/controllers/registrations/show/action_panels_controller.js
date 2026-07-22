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
    if (name) this.open(name, null, 0)
  }

  toggle (event) {
    event.preventDefault()
    const { panelName, panelMode } = event.currentTarget.dataset
    // Same trigger (name + mode) closes; a different mode of the same panel switches
    const sameTrigger = this.openName === panelName && this.openMode === (panelMode || null)
    this.open(sameTrigger ? null : panelName, panelMode)
  }

  open (name, mode = null, duration = 200) {
    this.panelTargets.forEach((panel) => {
      const show = panel.dataset.panelName === name
      collapse(show ? 'show' : 'hide', panel, duration)
      // Let the panel react to how it was opened (e.g. impound vs notification)
      if (show) this.dispatch('shown', { target: panel, detail: { mode } })
    })
    // The active trigger matches both the open panel and the mode it opened;
    // aria-expanded for disclosure semantics, aria-pressed drives active styling
    this.triggerTargets.forEach((trigger) => {
      const active = String(trigger.dataset.panelName === name && (trigger.dataset.panelMode || null) === (mode || null))
      trigger.setAttribute('aria-expanded', active)
      trigger.setAttribute('aria-pressed', active)
    })
    this.openName = name
    this.openMode = mode || null
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
