import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='page-preview'
// The preview reflects the saved page, so the moment the form is edited it's
// stale: hide the preview card and show a "save to refresh" hint instead.
export default class extends Controller {
  static targets = ['preview', 'hint']

  connect () {
    this.markStale = this.markStale.bind(this)
    // input bubbles from the text fields and the contenteditable bullets; change covers
    // the checkbox and file inputs. Both are user-driven, so neither fires as Lexxy upgrades.
    this.element.addEventListener('input', this.markStale)
    this.element.addEventListener('change', this.markStale)
  }

  disconnect () {
    this.element.removeEventListener('input', this.markStale)
    this.element.removeEventListener('change', this.markStale)
  }

  markStale () {
    if (this.hasPreviewTarget) this.previewTarget.hidden = true
    if (this.hasHintTarget) this.hintTarget.hidden = false
  }
}
