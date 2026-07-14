import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='registrations--new--propulsion'
//
// Mirrors the registration embed's UpdatePropulsionType: the electric checkbox is
// forced on/off (and disabled) for always/never-motorized vehicle types, and the
// throttle/pedal-assist options only show for motorized pedal vehicles.
export default class extends Controller {
  static targets = ['cycleType', 'motorized', 'motorizedWrapper', 'propulsionFields']
  static values = { pedal: Array, alwaysMotorized: Array, neverMotorized: Array }

  connect () {
    this.update()
  }

  update () {
    const cycleType = this.cycleTypeTarget.value
    if (this.alwaysMotorizedValue.includes(cycleType)) {
      this.setMotorized({ checked: true, enabled: false })
    } else if (this.neverMotorizedValue.includes(cycleType)) {
      this.setMotorized({ checked: false, enabled: false })
    } else {
      this.setMotorized({ checked: this.motorizedTarget.checked, enabled: true })
    }
  }

  setMotorized ({ checked, enabled }) {
    this.motorizedTarget.checked = checked
    this.motorizedTarget.disabled = !enabled
    this.motorizedWrapperTarget.classList.toggle('tw:opacity-60', !enabled)

    const showPropulsion = checked && this.pedalValue.includes(this.cycleTypeTarget.value)
    collapse(showPropulsion ? 'show' : 'hide', this.propulsionFieldsTarget)
    if (!checked) {
      this.propulsionFieldsTarget.querySelectorAll('input').forEach(input => { input.checked = false })
    }
  }
}
