import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global localStorage */

// Connects to data-controller='ui--collapse'
// Animates [data-ui--collapse-target=content] open/closed. Optionally rotates a
// [data-ui--collapse-target=chevron] and keeps [data-ui--collapse-target=trigger]'s
// aria-expanded and data-active (the is-active variant) in sync. With
// data-ui--collapse-param-value set, the open state persists to the URL query
// (?param=1) so it survives reloads and navigation; with
// data-ui--collapse-storage-key-value it persists to localStorage instead, for a panel
// whose state is the rider's preference rather than part of the address.
export default class extends Controller {
  static targets = ['content', 'chevron', 'trigger']
  static values = { param: String, storageKey: String }

  connect () {
    // Restore the open state without animating on load.
    if (this.hasParamValue && this.paramInUrl) return this.setExpanded(true, 0)
    if (this.hasStorageKeyValue) return this.setExpanded(this.stored, 0)

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

  get paramInUrl () {
    return new URLSearchParams(window.location.search).has(this.paramValue)
  }

  get stored () {
    return localStorage.getItem(this.storageKeyValue) === 'true'
  }

  // duration 0 restores state without animating
  setExpanded (expanding, duration) {
    collapse(expanding ? 'show' : 'hide', this.contentTargets, duration)
    this.syncTriggers(expanding)
    this.persist(expanding)
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
    if (expanding) {
      url.searchParams.set(this.paramValue, '1')
    } else {
      url.searchParams.delete(this.paramValue)
    }
    // replaceState (not pushState) so a toggle doesn't stack history entries.
    window.history.replaceState(window.history.state, '', url)
  }
}
