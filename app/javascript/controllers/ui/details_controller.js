import { Controller } from '@hotwired/stimulus'
import { collapse, COLLAPSE_DURATION_MS } from 'utils/collapse_utils'

// Connects to data-controller='ui--details'
// Animates a native <details> open/close via collapse_utils while keeping its
// `open` attribute (and the CSS keyed off it) in sync. Closing stays open until
// the animation finishes, otherwise the browser hides the content instantly.
// Without JS the <summary> still toggles natively; this only layers on animation.
export default class extends Controller {
  static targets = ['content']

  toggle (event) {
    event.preventDefault()
    clearTimeout(this.closeTimer)

    if (this.element.open) {
      collapse('hide', this.contentTarget)
      this.closeTimer = setTimeout(() => { this.element.open = false }, COLLAPSE_DURATION_MS)
    } else {
      this.element.open = true
      collapse('show', this.contentTarget)
    }
  }
}
