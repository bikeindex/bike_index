import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--impound-settings'
// Without JS the form works as before, showing the saved next ID
export default class extends Controller {
  static targets = ['prefix', 'nextId', 'unsaved']
  static values = { savedPrefix: String, nextIds: Object }

  connect () {
    this.savedMarkup = this.nextIdTarget.innerHTML
    this.preview()
  }

  preview () {
    const changed = this.prefixTarget.value !== this.savedPrefixValue
    // A prefix with no records starts at 1; the saved ID is the server's markup
    const prefix = this.prefixTarget.value
    if (changed) this.nextIdTarget.querySelector('code').textContent = `${prefix}${this.nextIdsValue[prefix] ?? 1}`
    else this.nextIdTarget.innerHTML = this.savedMarkup
    this.unsavedTarget.classList.toggle('tw:hidden', !changed)
  }

  use ({ params: { prefix } }) {
    this.prefixTarget.value = prefix
    this.preview()
  }
}
