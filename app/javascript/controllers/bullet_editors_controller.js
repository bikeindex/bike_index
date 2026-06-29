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

  // Drag-to-reorder by swapping editor *content* on drop. We never relocate the lexxy-editor
  // nodes: moving one fires its disconnect/connect callbacks, which crash Lexxy mid-drag.
  // Editors stay mounted; only their values (and thus the composed body) shuffle.
  handleTargetConnected (handle) {
    const item = handle.closest('[data-bullet-editors-target="bullet"]')
    handle.addEventListener('dragstart', event => {
      this.#dragging = item
      event.dataTransfer.effectAllowed = 'move'
      event.dataTransfer.setData('text/plain', '')
      setTimeout(() => item.classList.add('tw:opacity-50'), 0)
    })
    handle.addEventListener('dragend', () => {
      item.classList.remove('tw:opacity-50')
      this.#dragging = null
    })
  }

  bulletTargetConnected (item) {
    item.addEventListener('dragover', event => {
      if (!this.#dragging) return
      event.preventDefault()
      event.dataTransfer.dropEffect = 'move'
    })
    item.addEventListener('drop', event => {
      if (!this.#dragging || item === this.#dragging) return
      event.preventDefault()
      this.#reorder(item, event.clientY)
    })
  }

  #reorder (target, clientY) {
    const items = this.bulletTargets
    const editors = items.map(item => item.querySelector('lexxy-editor'))
    const values = editors.map(editor => editor?.value ?? '')
    const from = items.indexOf(this.#dragging)
    const box = target.getBoundingClientRect()
    let to = items.indexOf(target) + (clientY > box.top + box.height / 2 ? 1 : 0)
    if (to > from) to -= 1
    if (from === to) return

    const [moved] = values.splice(from, 1)
    values.splice(to, 0, moved)
    editors.forEach((editor, i) => { if (editor && editor.value !== values[i]) editor.value = values[i] })
    this.compose()
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
