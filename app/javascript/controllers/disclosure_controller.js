import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='disclosure'
// Toggles [data-disclosure-target=content] visibility and rotates [data-disclosure-target=chevron],
// keeping the toggling button's aria-expanded in sync.
export default class extends Controller {
  static targets = ['content', 'chevron']

  toggle (event) {
    const expanding = this.contentTargets.every((content) => content.classList.contains('tw:hidden'))
    this.contentTargets.forEach((content) => content.classList.toggle('tw:hidden', !expanding))
    this.chevronTargets.forEach((chevron) => chevron.classList.toggle('tw:rotate-90', expanding))
    event.currentTarget.setAttribute('aria-expanded', String(expanding))
  }
}
