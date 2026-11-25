import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global window */

// Connects to data-controller='register--frame-size'
//
// Frame size is either an ordinal chip (XS-XL) or a number - picking one clears
// the other so only a single size is submitted, and dims it.
export default class extends Controller {
  static targets = ['chip', 'chips', 'number', 'measure', 'unit', 'wrongUnit']

  connect () {
    // form-persist restores a drafted chip or number by assignment, firing no event
    this.boundDim = () => this.dim()
    window.addEventListener('form-persist:restored', this.boundDim)
    this.dim()
  }

  disconnect () {
    window.removeEventListener('form-persist:restored', this.boundDim)
  }

  pickChip () {
    this.numberTarget.value = ''
    collapse('hide', this.wrongUnitTargets)
    this.dim()
  }

  pickNumber () {
    if (this.numberTarget.value !== '') this.chipTargets.forEach(chip => { chip.checked = false })
    this.dim()
  }

  dim () {
    this.chipsTarget.classList.toggle('tw:opacity-60', this.numberTarget.value !== '')
    this.measureTarget.classList.toggle('tw:opacity-60', this.chipTargets.some(chip => chip.checked))
  }

  // On change rather than input: typing 56 passes through 5 on its way there
  checkUnit () {
    const size = parseFloat(this.numberTarget.value)
    if (!(size > 0)) return

    const unit = size >= 30 ? 'cm' : 'in' // Bike#clean_frame_size's split
    if (unit === this.unitTarget.value) return

    this.unitTarget.value = unit
    this.wrongUnitTargets.forEach(message => collapse(message.dataset.unit === unit ? 'hide' : 'show', message))
  }

  // Dispatched so form-persist saves it, and pickUnit hides the message
  revert ({ currentTarget }) {
    this.unitTarget.value = currentTarget.value
    this.unitTarget.dispatchEvent(new Event('change', { bubbles: true }))
  }

  pickUnit () {
    collapse('hide', this.wrongUnitTargets)
  }
}
