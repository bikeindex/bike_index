import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='recovery-stories--gift-picker'
export default class extends Controller {
  static targets = ['cta']

  update (event) {
    this.ctaTarget.textContent = event.target.dataset.label
  }
}
