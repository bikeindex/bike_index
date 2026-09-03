import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='register--propulsion'
//
// Mirrors the registration embed's UpdatePropulsionType: the electric checkbox
// is forced on/off (and disabled) for always/never-motorized vehicle types.
export default class extends Controller {
  static targets = ['motorized', 'motorizedWrapper']
  static values = { alwaysMotorized: Array, neverMotorized: Array }

  // Modules load lazily, so this one can arrive after the selection - or after
  // form-persist has announced the restore that filled the combobox
  connect () {
    this.update()
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
