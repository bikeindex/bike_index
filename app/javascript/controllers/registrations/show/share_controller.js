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

    try {
      await navigator.clipboard.writeText(url)
      this.flashCopied()
    } catch (error) {
      // Clipboard denied or unavailable (e.g. an insecure context)
    }
  }

  flashCopied () {
    const label = this.hasLabelTarget ? this.labelTarget : this.element
    // Read once, so a second click mid-flash doesn't keep "Link copied" as the label
    this.originalLabel ??= label.textContent
    label.textContent = this.copiedValue || 'Link copied'
    clearTimeout(this.resetTimeout)
    this.resetTimeout = setTimeout(() => { label.textContent = this.originalLabel }, 1500)
  }
}
