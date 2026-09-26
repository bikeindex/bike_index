import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='register--landing-donation'
//
// Points the call to action at the picked tile for the chosen cadence, or at the
// donate page for a custom one-time amount, and names the amount on it
export default class extends Controller {
  static targets = ['custom', 'cta']
  static values = { customHref: String, customLabel: String }

  connect () {
    this.update()
  }

  select () {
    this.customTarget.value = ''
    this.update()
  }

  // A custom amount stands in for the one-time tiles, and clearing it puts the default back
  customize () {
    const cleared = !(parseInt(this.customTarget.value, 10) > 0)
    this.element.querySelectorAll('[data-amount-for="one_time"]').forEach((radio) => {
      radio.checked = cleared && radio.defaultChecked
    })
    this.update()
  }

  update () {
    const cadence = this.element.querySelector('[data-cadence]:checked')?.value
    const picked = this.element.querySelector(`[data-amount-for="${cadence}"]:checked`)
    const custom = parseInt(this.customTarget.value, 10)

    if (picked) {
      this.show(picked.dataset.href, picked.dataset.label)
    } else if (cadence === 'one_time' && custom > 0) {
      this.show(`${this.customHrefValue}?initial_amount=${custom}`, this.customLabelValue.replace('%{amount}', custom))
    }
  }

  show (href, label) {
    this.ctaTarget.href = href
    this.ctaTarget.textContent = label
  }
}
