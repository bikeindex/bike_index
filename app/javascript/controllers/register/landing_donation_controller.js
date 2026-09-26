import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='register--landing-donation'
//
// Points the call to action at the picked tile for the chosen cadence, or at the
// donate page for a custom one-time amount
export default class extends Controller {
  static targets = ['custom', 'cta']
  static values = { customHref: String, customLabel: String }

  connect () {
    this.update()
  }

  get custom () {
    return parseInt(this.customTarget.value, 10) || 0
  }

  select () {
    this.customTarget.value = ''
    this.update()
  }

  // A custom amount stands in for the one-time tiles, and clearing it puts the default back
  customize () {
    this.element.querySelectorAll('[name=landing_donation_one_time]').forEach((radio) => {
      radio.checked = this.custom <= 0 && radio.defaultChecked
    })
    this.update()
  }

  update () {
    const cadence = this.element.querySelector('[name=landing_donation_cadence]:checked')?.value
    const picked = this.element.querySelector(`[name=landing_donation_${cadence}]:checked`)

    if (picked) {
      this.show(picked.dataset.href, picked.dataset.label)
    } else if (cadence === 'one_time' && this.custom > 0) {
      this.show(`${this.customHrefValue}?initial_amount=${this.custom}`, this.customLabelValue.replace('%{amount}', this.custom))
    }
  }

  show (href, label) {
    this.ctaTarget.href = href
    this.ctaTarget.textContent = label
  }
}
