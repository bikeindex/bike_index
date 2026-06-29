import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='bullet-editors'
// The page model stores its bullets as a single `body` HTML string (a <ul> of <li>s).
// These per-bullet editors are purely a frontend convenience: we recombine them into the
// hidden body field on every change and before submit, leaving the backend contract unchanged.
export default class extends Controller {
  static targets = ['field', 'list', 'template', 'bullet', 'handle']

  #counter = 0
  #dragging = null

  connect () {
    this.element.addEventListener('lexxy:change', this.compose)
    this.form?.addEventListener('submit', this.compose)
  }

  disconnect () {
    this.element.removeEventListener('lexxy:change', this.compose)
    this.form?.removeEventListener('submit', this.compose)
  }

  add (event) {
    event.preventDefault()
    const markup = this.templateTarget.innerHTML.replaceAll('__INDEX__', `new_${this.#counter++}`)
    this.listTarget.insertAdjacentHTML('beforeend', markup)
  }

  remove (event) {
    event.preventDefault()
    event.currentTarget.closest('[data-bullet-editors-target="bullet"]').remove()
    this.compose()
  }

  focusFirst (event) {
    event.preventDefault()
    // Focus the contenteditable directly -- the host's focus() defers to Lexical and no-ops here
    this.bulletTargets[0]?.querySelector('lexxy-editor [contenteditable]')?.focus()
  }

  // Drag-to-reorder, mirroring sortable_controller but recomposing the body locally
  // instead of persisting -- bullets live only in the body string, so order is just DOM order.
  handleTargetConnected (handle) {
    const item = handle.closest('[data-bullet-editors-target="bullet"]')
    handle.addEventListener('dragstart', event => {
      this.#dragging = item
      const rect = item.getBoundingClientRect()
      event.dataTransfer.setDragImage(item, event.clientX - rect.left, event.clientY - rect.top)
      // Defer dimming so the full row is captured as the drag image first
      setTimeout(() => item.classList.add('tw:opacity-50'), 0)
    })
    handle.addEventListener('dragend', () => {
      item.classList.remove('tw:opacity-50')
      this.#dragging = null
      this.compose()
    })
  }

  bulletTargetConnected (item) {
    item.addEventListener('dragover', event => {
      event.preventDefault()
      if (!this.#dragging) return
      const after = this.#afterElement(event.clientY)
      if (after == null) this.listTarget.appendChild(this.#dragging)
      else this.listTarget.insertBefore(this.#dragging, after)
    })
  }

  #afterElement (y) {
    return this.bulletTargets
      .filter(item => item !== this.#dragging)
      .reduce((closest, item) => {
        const box = item.getBoundingClientRect()
        const offset = y - box.top - box.height / 2
        if (offset < 0 && offset > closest.offset) return { offset, element: item }
        return closest
      }, { offset: Number.NEGATIVE_INFINITY, element: null }).element
  }

  // Arrow so it survives being passed as an event listener
  compose = () => {
    const editors = this.bulletTargets
      .map(bullet => bullet.querySelector('lexxy-editor'))
      .filter(Boolean)
    // Editors upgrade asynchronously; bail until every one exposes a value so the first
    // paint never clobbers the server-rendered body with empties.
    if (editors.some(editor => editor.value === undefined)) return

    const items = editors
      .map(editor => this.#clean(editor.value))
      .filter(content => content.length)
      .map(content => `<li>${content}</li>`)
    this.fieldTarget.value = items.length ? `<ul>${items.join('')}</ul>` : ''
  }

  get form () {
    return this.element.closest('form')
  }

  // Drop the single wrapping <p> the editor adds so each bullet stays a clean inline <li>
  #clean (html) {
    return (html || '').trim().replace(/^<p>([\s\S]*?)<\/p>$/i, '$1').trim()
  }
}
