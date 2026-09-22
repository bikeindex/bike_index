import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global localStorage */

// Connects to data-controller='ui--collapse'
// Animates [data-ui--collapse-target=content] open/closed. Optionally rotates a
// [data-ui--collapse-target=chevron] and keeps [data-ui--collapse-target=trigger]'s
// aria-expanded and data-active (the is-active variant) in sync. With
// data-ui--collapse-param-value set, the open state persists to the URL query
// (?param=1, ?param=0 collapsed) so it survives reloads and navigation; with
// data-ui--collapse-storage-key-value it persists to localStorage instead, for a panel
// whose state is the rider's preference rather than part of the address.
export default class extends Controller {
  static targets = ['content', 'chevron', 'trigger']
  static values = { param: String, storageKey: String }

  connect () {
    // Restore the persisted state without animating on load. Restoring applies rather than
    // sets: persisting here would only write back what it just read.
    if (this.urlExpanded !== null) return this.applyExpanded(this.urlExpanded, 0)
    if (this.hasStorageKeyValue) return this.applyExpanded(this.stored, 0)

    // The server can render the content open -- a panel whose state is part of the
    // response rather than a preference. Only the trigger needs catching up, and it
    // mustn't persist: writing the param here would put it in a URL nobody asked it of.
    this.syncTriggers(!this.collapsed)
  }

  toggle () {
    this.setExpanded(this.collapsed)
  }

  show () {
    this.setExpanded(true)
  }

  hide () {
    this.setExpanded(false)
  }

  get collapsed () {
    return this.contentTargets.every((content) =>
      content.classList.contains('tw:hidden') || content.classList.contains('tw:hidden!'))
  }

  // null when there's no param to read, so the rendered state stands.
  get urlExpanded () {
    if (!this.hasParamValue) return null

    const value = new URLSearchParams(window.location.search).get(this.paramValue)
    if (value === null) return null

    return !['', '0', 'false'].includes(value)
  }

  get stored () {
    return localStorage.getItem(this.storageKeyValue) === 'true'
  }

  // duration 0 restores state without animating
  setExpanded (expanding, duration) {
    this.applyExpanded(expanding, duration)
    this.persist(expanding)
  }

  applyExpanded (expanding, duration) {
    collapse(expanding ? 'show' : 'hide', this.contentTargets, duration)
    this.syncTriggers(expanding)
  }

  syncTriggers (expanding) {
    this.chevronTargets.forEach((chevron) => chevron.classList.toggle('tw:rotate-90', expanding))
    this.triggerTargets.forEach((trigger) => {
      trigger.setAttribute('aria-expanded', String(expanding))
      trigger.dataset.active = String(expanding)
    })
  }

  persist (expanding) {
    if (this.hasStorageKeyValue) localStorage.setItem(this.storageKeyValue, String(expanding))
    if (!this.hasParamValue) return
    const url = new URL(window.location)
    // Collapsed writes 0 rather than dropping the param: a caller rebuilding the query
    // string from its own fields can't copy an absent one forward.
    url.searchParams.set(this.paramValue, expanding ? '1' : '0')
    // replaceState (not pushState) so a toggle doesn't stack history entries.
    window.history.replaceState(window.history.state, '', url)
  }
}
