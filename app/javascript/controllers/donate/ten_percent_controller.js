import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='donate--ten-percent'
// Fills the donate form's other amount with 10% of the bike's value typed here. The
// ui--collapse controller on the same element opens the panel; this one fills and focuses
export default class extends Controller {
  static targets = ['value', 'result', 'amount']
  static values = { currencySymbol: String }

  fill () {
    const value = parseFloat(this.valueTarget.value)
    const tenth = value > 0 ? Math.max(1, Math.round(value * 0.1)) : null
    // A gift over the form's max would only be refused at the server
    const ten = tenth <= parseFloat(this.customAmount.max) ? tenth : null
    this.amountTarget.textContent = ten ? this.currencySymbolValue + ten.toLocaleString('en-US') : ''
    collapse(ten ? 'show' : 'hide', this.resultTarget)
    // donate--form's customInput takes it from the input event, as if it were typed there
    this.filled = ten ? String(ten) : ''
    this.customAmount.value = this.filled
    this.customAmount.dispatchEvent(new Event('input', { bubbles: true }))
  }

  // Choosing or typing another amount leaves the helper claiming a gift that isn't the one below
  formChanged () {
    if (!this.valueTarget.value || this.customAmount.value === this.filled) return

    this.valueTarget.value = ''
    collapse('hide', this.resultTarget)
  }

  // The helper is on the one-time tab
  focus () {
    const oneTime = document.getElementById('donate-cadence-one-time')
    if (oneTime && !oneTime.checked) oneTime.click()
    this.valueTarget.focus({ preventScroll: true })
  }

  get customAmount () {
    return this.element.parentElement.querySelector('[data-donate--form-target="customAmount"]')
  }
}
