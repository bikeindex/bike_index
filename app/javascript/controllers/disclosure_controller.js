import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='disclosure'
// Animates [data-disclosure-target=content] open/closed via collapse_utils and rotates
// [data-disclosure-target=chevron], keeping the toggling button's aria-expanded in sync.
export default class extends Controller {
  static targets = ['content', 'chevron']
  static values = { duration: { type: Number, default: 200 } }

  toggle (event) {
    const expanding = this.contentTargets.every((content) =>
      content.classList.contains('tw:hidden') || content.classList.contains('tw:hidden!'))
    collapse('toggle', this.contentTargets, this.durationValue)
    this.chevronTargets.forEach((chevron) => chevron.classList.toggle('tw:rotate-90', expanding))
    event.currentTarget.setAttribute('aria-expanded', String(expanding))
  }
}
