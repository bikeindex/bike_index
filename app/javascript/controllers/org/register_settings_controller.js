import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--register-settings'
// The old view skips the register flow, so its settings don't apply while it's checked
export default class extends Controller {
  static targets = ['oldView', 'flowSettings']

  connect () {
    this.apply()
  }

  apply () {
    const off = this.oldViewTarget.checked
    this.flowSettingsTarget.classList.toggle('tw:opacity-50', off)
    this.flowSettingsTarget.querySelectorAll('input').forEach(input => { input.disabled = off })
  }
}
