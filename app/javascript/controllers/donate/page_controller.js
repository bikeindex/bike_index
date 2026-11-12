import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='donate--page'
// The major gift cards, the closing CTA and the 10% button, relayed to and from Pages::Donate::Form's controller
export default class extends Controller {
  static targets = ['majorGift', 'submit']

  // donate--form loads separately and claims these by canceling them. Until it has, a card
  // follows its link and the closing CTA goes to the form
  selectMajor (event) {
    const { defaultPrevented } = this.dispatch('select-amount', { target: window, detail: { amount: event.currentTarget.dataset.amount } })
    if (defaultPrevented) event.preventDefault()
  }

  submit () {
    const { defaultPrevented } = this.dispatch('submit', { target: window })
    if (!defaultPrevented) document.getElementById('donate-form').scrollIntoView({ behavior: 'smooth' })
  }

  // Scrolls without waiting for donate--ten-percent, which loads separately
  openTenPercent () {
    this.dispatch('open-ten-percent', { target: window })
    document.getElementById('donate-form').scrollIntoView({ behavior: 'smooth' })
  }

  formChanged ({ detail: { label, customAmount } }) {
    this.submitTargets.forEach(button => { button.textContent = label })
    this.majorGiftTargets.forEach(card => { card.dataset.active = card.dataset.amount === customAmount })
  }
}
