import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='register--frame-size'
//
// Frame size is either an ordinal chip (XS-XL) or a number in inches - picking
// one clears the other so only a single size is submitted.
export default class extends Controller {
  static targets = ['chip', 'number']

  pickChip () {
    this.numberTarget.value = ''
  }

  pickNumber () {
    if (this.numberTarget.value === '') return

    this.chipTargets.forEach(chip => { chip.checked = false })
  }
}
