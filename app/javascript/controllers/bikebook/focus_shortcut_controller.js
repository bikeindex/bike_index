import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='bikebook--focus-shortcut'
// Jumps to the field target when "/" is pressed, the way a search box on a
// listing page does. Listens on the document, so the key works from anywhere on
// the page — and stands aside whenever the visitor is already typing, since "/"
// is an ordinary character in a field.
export default class extends Controller {
  static targets = ['field']

  connect () {
    document.addEventListener('keydown', this.focusField)
  }

  disconnect () {
    document.removeEventListener('keydown', this.focusField)
  }

  focusField = (event) => {
    if (event.key !== '/' || event.metaKey || event.ctrlKey || event.altKey) return

    const active = document.activeElement
    if (active && (active.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(active.tagName))) return

    event.preventDefault()
    this.fieldTarget.focus()
  }
}
