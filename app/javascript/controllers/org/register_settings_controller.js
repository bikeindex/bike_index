import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--register-settings'
// The old view bypasses these settings; each shows what it does instead (data-old-view-checked)
export default class extends Controller {
  static targets = ['oldView', 'oldViewShown']

  connect () {
    this.apply()
  }

  apply () {
    const off = this.oldViewTarget.checked
    this.oldViewShownTargets.forEach(box => {
      this.showOldView(box, off)
      box.disabled = off
    })
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
