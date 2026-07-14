import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='registrations--new--propulsion'
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
  }
}
