import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// The figure each card's note was on as last rendered, which the next render's collapses from
const shown = new Map()

// Connects to data-controller='bikebook--figure-note'
// A card's note on its lit figure, rendered afresh each time the page is, so the last one's collapses out and this
// one's in
export default class extends Controller {
  static targets = ['note']
  static values = { card: String }

  connect () {
    const current = this.noteTargets.find((note) => !note.classList.contains('tw:hidden'))
    const was = shown.get(this.cardValue)
    if (shown.has(this.cardValue) && was !== current?.dataset.figure) {
      const previous = this.noteTargets.find((note) => note.dataset.figure === was)
      previous?.classList.remove('tw:hidden')
      current?.classList.add('tw:hidden')
      if (previous) collapse('hide', previous)
      if (current) collapse('show', current)
    }
    shown.set(this.cardValue, current?.dataset.figure)
  }
}
