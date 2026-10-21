import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='donate--page'
// The major gift cards and the closing CTA, relayed to and from Pages::Donate::Form's controller
export default class extends Controller {
  static targets = ['majorGift', 'submit']

  selectMajor (event) {
    event.preventDefault()
    this.dispatch('select-amount', { target: window, detail: { amount: event.currentTarget.dataset.amount } })
  }

  submit () {
    this.dispatch('submit', { target: window })
  }

  formChanged ({ detail: { label, customAmount } }) {
    this.submitTargets.forEach(button => { button.textContent = label })
    this.majorGiftTargets.forEach(card => { card.dataset.active = card.dataset.amount === customAmount })
  }
}
