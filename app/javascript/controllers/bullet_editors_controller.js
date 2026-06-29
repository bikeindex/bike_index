import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='bullet-editors'
// The page model stores its bullets as a single `body` HTML string (a <ul> of <li>s).
// These per-bullet editors are purely a frontend convenience: we recombine them into the
// hidden body field on every change and before submit, leaving the backend contract unchanged.
export default class extends Controller {
  static targets = ['field', 'list', 'template', 'bullet']

  #counter = 0

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
