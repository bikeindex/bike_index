import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='bikebook--focus-shortcut'
// "/" focuses the field target from anywhere on the page, except while typing in a field
export default class extends Controller {
  static targets = ['field']

  connect () {
    document.addEventListener('keydown', this.focusField)
  }

  disconnect () {
    document.removeEventListener('keydown', this.focusField)
  }

  // Opens the field's list, after the click that asked, which it would otherwise close as one outside it, scrolled to
  // where it's out of view. A field already focused wouldn't scroll to itself
  open () {
    setTimeout(() => {
      this.element.scrollIntoView({ block: 'nearest' })
      this.fieldTarget.focus({ preventScroll: true })
      this.fieldTarget.click()
    })
  }

  focusField = (event) => {
    if (event.key !== '/' || event.metaKey || event.ctrlKey || event.altKey) return

    const active = document.activeElement
    if (active && (active.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(active.tagName))) return

    event.preventDefault()
    this.fieldTarget.focus()
  }
}
