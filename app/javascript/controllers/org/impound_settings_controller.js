import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--impound-settings'
// Without JS the form works as before, showing the saved next ID
export default class extends Controller {
  static targets = ['prefix', 'nextId', 'unsaved']
  static values = { savedPrefix: String, nextIds: Object }

  connect () {
    this.preview()
  }

  preview () {
    const prefix = this.prefixTarget.value
    this.nextIdTarget.querySelector('code').textContent = `${prefix}${this.nextIdsValue[prefix] ?? 1}`
    this.unsavedTarget.classList.toggle('tw:hidden', prefix === this.savedPrefixValue)
  }

  use ({ params: { prefix } }) {
    this.prefixTarget.value = prefix
    this.preview()
  }
}
