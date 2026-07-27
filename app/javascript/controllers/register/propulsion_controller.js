import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='register--propulsion'
//
// Mirrors the registration embed's UpdatePropulsionType: the electric checkbox
// is forced on/off (and disabled) for always/never-motorized vehicle types.
export default class extends Controller {
  static targets = ['motorized', 'motorizedWrapper']
  static values = { alwaysMotorized: Array, neverMotorized: Array }

  connect () {
    this.element.addEventListener('hw-combobox:selection', this.update)
    this.update()
  }

  disconnect () {
    this.element.removeEventListener('hw-combobox:selection', this.update)
  }

  update = () => {
    const cycleType = this.element.querySelector('input[name$="[cycle_type]"]')?.value
    const forced = this.alwaysMotorizedValue.includes(cycleType)
      ? true
      : (this.neverMotorizedValue.includes(cycleType) ? false : null)

    if (forced !== null) this.motorizedTarget.checked = forced
    this.motorizedTarget.disabled = forced !== null
    this.motorizedWrapperTarget.classList.toggle('tw:opacity-60', forced !== null)
  }
}
