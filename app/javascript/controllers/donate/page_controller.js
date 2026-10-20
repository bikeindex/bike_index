import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='donate--page'
// The cadence radios show and hide the two forms in CSS; this keeps every submit label on
// the selected amount, and unchecks the presets while an other amount is typed
export default class extends Controller {
  static targets = ['cadence', 'monthlyForm', 'oneTimeForm', 'oneTimeAmount', 'customAmount', 'majorGift', 'submit']
  static values = { monthlyLabel: String, oneTimeLabel: String, currencySymbol: String }

  connect () {
    // [1] is $50, the server's default when an other amount came in instead
    this.lastPreset = this.oneTimeAmountTargets.find(radio => radio.checked) || this.oneTimeAmountTargets[1]
    this.update()
  }

  selectPreset (event) {
    this.lastPreset = event.currentTarget
    this.customAmountTarget.value = ''
    this.update()
  }

  customInput () {
    const hasCustom = this.customDollars() > 0
    this.oneTimeAmountTargets.forEach(radio => { radio.checked = !hasCustom && radio === this.lastPreset })
    this.update()
  }

  selectMajor (event) {
    event.preventDefault()
    const oneTime = this.cadenceTargets.find(radio => radio.value === 'one-time')
    if (oneTime) oneTime.checked = true
    this.customAmountTarget.value = event.currentTarget.dataset.amount
    this.customInput()
    this.element.querySelector('#donate-form').scrollIntoView({ behavior: 'smooth' })
  }

  submitActive () {
    const form = this.isOneTime ? this.oneTimeFormTarget : this.monthlyFormTarget
    form.requestSubmit()
  }

  update () {
    const isOneTime = this.isOneTime
    const label = isOneTime ? this.oneTimeLabelValue : this.monthlyLabelValue
    const text = label.replace('%{amount}', this.selectedAmount(isOneTime))
    this.submitTargets.forEach(button => { button.textContent = text })

    const customDollars = isOneTime && this.customAmountTarget.value
    this.majorGiftTargets.forEach(card => {
      card.dataset.active = card.dataset.amount === customDollars
    })
  }

  // Without a monthly form there are no cadence tabs, only the one-time form
  get isOneTime () {
    return !this.hasMonthlyFormTarget || this.cadenceTargets.find(radio => radio.checked)?.value === 'one-time'
  }

  customDollars () {
    return parseFloat(this.customAmountTarget.value)
  }

  // Formats the way MoneyFormatter does the server-rendered presets
  selectedAmount (isOneTime) {
    const dollars = this.customDollars()
    if (isOneTime && dollars > 0) {
      const digits = Number.isInteger(dollars) ? 0 : 2
      return this.currencySymbolValue + dollars.toLocaleString('en-US', { minimumFractionDigits: digits, maximumFractionDigits: digits })
    }
    const form = isOneTime ? this.oneTimeFormTarget : this.monthlyFormTarget
    return form.querySelector('input[type="radio"]:checked')?.dataset.amount || ''
  }
}
