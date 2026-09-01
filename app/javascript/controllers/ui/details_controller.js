import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ui--details'
// Animates a native <details> open/close via collapse_utils while keeping its
// `open` attribute (and the CSS keyed off it) in sync. Closing stays open until
// the animation finishes, otherwise the browser hides the content instantly.
// Without JS the <summary> still toggles natively; this only layers on animation.

// Passed to collapse() rather than left to its default, so the close timer below can't
// fall out of step with the animation it waits for
const DURATION_MS = 200

export default class extends Controller {
  static targets = ['content']

  toggle (event) {
    event.preventDefault()
    clearTimeout(this.closeTimer)

    if (this.element.open) {
      collapse('hide', this.contentTarget, DURATION_MS)
      this.closeTimer = setTimeout(() => { this.element.open = false }, DURATION_MS)
    } else {
      this.element.open = true
      collapse('show', this.contentTarget, DURATION_MS)
    }
  }
}
