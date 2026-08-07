import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='register--heading'
//
// Keeps "Register your bike!" in step with the vehicle type combobox. The
// heading sits outside the form, so it's scoped to the whole page rather than
// re-rendered - names maps each cycle_type slug to the word the heading uses.
export default class extends Controller {
  static targets = ['cycleType']
  static values = { names: Object }

  update () {
    const slug = this.element.querySelector('input[name$="[cycle_type]"]')?.value
    const name = this.namesValue[slug]
    if (name) this.cycleTypeTargets.forEach((target) => { target.textContent = name })
  }
}
