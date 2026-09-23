import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='donate--page'
// The cadence radios show and hide the two forms in CSS; this keeps every submit label on
// the selected amount, and moves the custom amount between the preset radios and its field
export default class extends Controller {
  static targets = ['cadence', 'monthlyForm', 'oneTimeForm', 'oneTimeAmount', 'customAmount', 'customCents', 'majorGift', 'submit']
  static values = { monthlyLabel: String, oneTimeLabel: String, currency: String }

  connect () {
    this.update()
  }

  selectPreset () {
    this.customAmountTarget.value = ''
    this.customInput()
  }

  customInput () {
    const dollars = parseFloat(this.customAmountTarget.value)
    const hasCustom = dollars > 0
    this.customCentsTarget.disabled = !hasCustom
    this.customCentsTarget.value = hasCustom ? Math.round(dollars * 100) : ''
    if (hasCustom) this.oneTimeAmountTargets.forEach(radio => { radio.checked = false })
    this.update()
  }

  selectMajor (event) {
    event.preventDefault()
    this.cadenceTargets.find(radio => radio.value === 'one-time').checked = true
    this.customAmountTarget.value = event.currentTarget.dataset.amount
    this.customInput()
    this.element.querySelector('#donate-form').scrollIntoView({ behavior: 'smooth' })
  }

  submitActive () {
    const form = this.isOneTime ? this.oneTimeFormTarget : this.monthlyFormTarget
    form.requestSubmit()
  }

  update () {
    const label = this.isOneTime ? this.oneTimeLabelValue : this.monthlyLabelValue
    const text = label.replace('%{amount}', this.selectedAmount())
    this.submitTargets.forEach(button => { button.textContent = text })

    const customDollars = this.isOneTime && this.customAmountTarget.value
    this.majorGiftTargets.forEach(card => {
      card.dataset.active = card.dataset.amount === customDollars
    })
  }

  // A member has no monthly form, so the page's own button gives one-time
  get isOneTime () {
    return !this.hasMonthlyFormTarget || this.cadenceTargets.find(radio => radio.checked)?.value === 'one-time'
  }

  selectedAmount () {
    if (this.isOneTime && !this.customCentsTarget.disabled) {
      const dollars = Number(this.customCentsTarget.value) / 100
      return new Intl.NumberFormat(document.documentElement.lang || 'en', {
        style: 'currency',
        currency: this.currencyValue,
        maximumFractionDigits: Number.isInteger(dollars) ? 0 : 2
      }).format(dollars)
    }
    const form = this.isOneTime ? this.oneTimeFormTarget : this.monthlyFormTarget
    return form.querySelector('input[type="radio"]:checked')?.dataset.amount || ''
  }
}
