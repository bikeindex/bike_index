import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='register--landing-donation'
//
// Puts the picked amount on each cadence's button, and submits a custom one-time amount
// in place of the tiles
export default class extends Controller {
  static targets = ['custom', 'customField', 'monthlyCta', 'oneTimeCta']
  static values = { customLabel: String, donateLabel: String }

  connect () {
    this.customFieldTarget.classList.replace('tw:hidden', 'tw:flex')
    this.lastPicked = this.oneTimeRadios.find((radio) => radio.checked)
    this.update()
  }

  get oneTimeRadios () {
    return [...this.element.querySelectorAll('[name=initial_amount]')]
  }

  // Whole dollars, as the donate page reads them
  get custom () {
    const amount = Number(this.customTarget.value)
    return Number.isInteger(amount) && amount > 0 ? amount : 0
  }

  // Anything typed, valid or not, so a bad amount doesn't fall back to a tile
  get customTyped () {
    return this.customTarget.value !== '' || this.customTarget.validity.badInput
  }

  select (event) {
    this.lastPicked = event.target
    this.customTarget.value = ''
    this.update()
  }

  // Clearing the amount puts back the tile that was picked before it
  customize () {
    this.oneTimeRadios.forEach((radio) => { radio.checked = !this.customTyped && radio === this.lastPicked })
    this.update()
  }

  formdata (event) {
    if (this.custom > 0) event.formData.set('initial_amount', this.custom)
  }

  update () {
    this.monthlyCtaTarget.textContent = this.element.querySelector('[name=membership_level]:checked').dataset.label
    this.oneTimeCtaTarget.textContent = this.oneTimeLabel()
  }

  oneTimeLabel () {
    const picked = this.oneTimeRadios.find((radio) => radio.checked)
    if (picked) return picked.dataset.label
    if (this.custom === 0) return this.donateLabelValue

    return this.customLabelValue.replace('%{amount}', this.custom.toLocaleString(document.documentElement.lang || undefined))
  }
}
