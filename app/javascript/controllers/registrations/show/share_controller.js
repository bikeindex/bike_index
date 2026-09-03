import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='registrations--show--share'
// Shares the page via the Web Share API, falling back to copying the URL to
// the clipboard and briefly swapping the label to registrations--show--share-copied-value.
export default class extends Controller {
  static values = { url: String, copied: String }
  static targets = ['label']

  async share (event) {
    event.preventDefault()
    const url = this.urlValue || window.location.href

    if (navigator.share) {
      try {
        await navigator.share({ url })
      } catch (error) {
        // Ignore - the user dismissed the share sheet
      }
      return
    }

    await navigator.clipboard.writeText(url)
    this.flashCopied()
  }

  flashCopied () {
    const label = this.hasLabelTarget ? this.labelTarget : this.element
    const original = label.textContent
    label.textContent = this.copiedValue || 'Link copied'
    clearTimeout(this.resetTimeout)
    this.resetTimeout = setTimeout(() => { label.textContent = original }, 1500)
  }
}
