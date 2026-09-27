import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--register-settings'
// The old view skips the register flow, so its settings don't apply while it's checked.
// Each shows what the old view does instead - data-old-view-checked - so the single page
// reads unchecked, and separate attestation checked, since it always leaves the rules to the owner
export default class extends Controller {
  static targets = ['oldView', 'flowSettings', 'oldViewShown']

  connect () {
    this.apply()
  }

  apply () {
    const off = this.oldViewTarget.checked
    this.oldViewShownTargets.forEach(box => this.showOldView(box, off))
    this.flowSettingsTarget.classList.toggle('tw:opacity-50', off)
    this.flowSettingsTarget.querySelectorAll('input').forEach(input => { input.disabled = off })
  }

  // Remembers what it was set to, for when the old view is unchecked
  showOldView (box, off) {
    if (off) {
      box.dataset.chosen ??= box.checked
      box.checked = box.dataset.oldViewChecked === 'true'
    } else if (box.dataset.chosen !== undefined) {
      box.checked = box.dataset.chosen === 'true'
      delete box.dataset.chosen
    }
  }
}
