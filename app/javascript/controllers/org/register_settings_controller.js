import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--register-settings'
// The old view skips the register flow, so its settings don't apply while it's checked -
// except that it always leaves the rules to the owner, so separate attestation shows checked
export default class extends Controller {
  static targets = ['oldView', 'flowSettings', 'separateAttestation']

  connect () {
    this.apply()
  }

  apply () {
    const off = this.oldViewTarget.checked
    if (this.hasSeparateAttestationTarget) this.showSeparateAttestation(off)
    this.flowSettingsTarget.classList.toggle('tw:opacity-50', off)
    this.flowSettingsTarget.querySelectorAll('input').forEach(input => { input.disabled = off })
  }

  // Remembers what it was set to, for when the old view is unchecked
  showSeparateAttestation (off) {
    const box = this.separateAttestationTarget
    if (off) {
      this.separateAttestationChosen ??= box.checked
      box.checked = true
    } else if (this.separateAttestationChosen !== undefined) {
      box.checked = this.separateAttestationChosen
      this.separateAttestationChosen = undefined
    }
  }
}
