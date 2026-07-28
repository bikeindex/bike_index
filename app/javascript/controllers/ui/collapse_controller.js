import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ui--collapse'
// Animates [data-ui--collapse-target=content] open/closed. Optionally rotates a
// [data-ui--collapse-target=chevron] and keeps [data-ui--collapse-target=trigger]'s
// aria-expanded and data-active (the is-active variant) in sync. With
// data-ui--collapse-param-value set, the open state
// persists to the URL query (?param=1) so it survives reloads and navigation.
export default class extends Controller {
  static targets = ['content', 'chevron', 'trigger']
  static values = { duration: { type: Number, default: 200 }, param: String }

  connect () {
    // Restore the open state from the URL without animating on load.
    if (this.hasParamValue && this.paramInUrl) this.setExpanded(true, 0)
  }

  toggle () {
    this.setExpanded(this.collapsed, this.durationValue)
  }

  show () {
    this.setExpanded(true, this.durationValue)
  }

  hide () {
    this.setExpanded(false, this.durationValue)
  }

  get collapsed () {
    return this.contentTargets.every((content) =>
      content.classList.contains('tw:hidden') || content.classList.contains('tw:hidden!'))
  }

  get paramInUrl () {
    return new URLSearchParams(window.location.search).has(this.paramValue)
  }

  setExpanded (expanding, duration) {
    collapse(expanding ? 'show' : 'hide', this.contentTargets, duration)
    this.chevronTargets.forEach((chevron) => chevron.classList.toggle('tw:rotate-90', expanding))
    this.triggerTargets.forEach((trigger) => {
      trigger.setAttribute('aria-expanded', String(expanding))
      trigger.dataset.active = String(expanding)
    })
    this.persist(expanding)
  }

  persist (expanding) {
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
