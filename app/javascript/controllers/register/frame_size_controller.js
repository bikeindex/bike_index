import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Bike#clean_frame_size guesses the unit from the same split
const CM_ABOVE = 30

// Connects to data-controller='register--frame-size'
//
// Frame size is either an ordinal chip (XS-XL) or a number - picking one clears
// the other so only a single size is submitted.
export default class extends Controller {
  static targets = ['chip', 'number', 'unit', 'wrongUnit', 'revert']

  pickChip () {
    this.numberTarget.value = ''
  }

  pickNumber () {
    if (this.numberTarget.value === '') return

    this.chipTargets.forEach(chip => { chip.checked = false })
  }

  // On change rather than input: typing 56 passes through 5 on its way there
  checkUnit () {
    const size = parseFloat(this.numberTarget.value)
    if (!(size > 0)) return

    const unit = size >= CM_ABOVE ? 'cm' : 'in'
    if (unit === this.unitTarget.value) return

    this.revertTargets.forEach(button => { button.hidden = button.value !== this.unitTarget.value })
    this.unitTarget.value = unit
    collapse('show', this.wrongUnitTarget)
  }

  // Dispatched so form-persist saves it, and pickUnit hides the message
  revert ({ currentTarget }) {
    this.unitTarget.value = currentTarget.value
    this.unitTarget.dispatchEvent(new Event('change', { bubbles: true }))
  }

  pickUnit () {
    collapse('hide', this.wrongUnitTarget)
  }
}
