import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='bullet-editors'
// The page model stores its bullets as a single `body` HTML string (a <ul> of <li>s).
// These per-bullet editors are a frontend convenience: we recombine them into the hidden
// body field on change and submit. Reorder uses pointer events and swaps editor *content*
// rather than moving rows -- relocating a lexxy editor crashes it, so SortableJS can't be
// used here the way it is on plain lists (sortable_controller).
export default class extends Controller {
  static targets = ['field', 'list', 'template', 'item', 'handle']

  #counter = 0

  connect () {
    this.element.addEventListener('lexxy:change', this.compose)
    this.form?.addEventListener('submit', this.compose)
    // Slid into the target gap during a drag; pointer-events:none so it never blocks hit-testing.
    this.indicator = document.createElement('div')
    this.indicator.setAttribute('aria-hidden', 'true')
    this.indicator.style.cssText = 'height:2px;border-radius:9999px;background:#2563eb;pointer-events:none;'
  }

  disconnect () {
    this.element.removeEventListener('lexxy:change', this.compose)
    this.form?.removeEventListener('submit', this.compose)
    this.#stopTracking()
  }

  add (event) {
    event.preventDefault()
    const markup = this.templateTarget.innerHTML.replaceAll('__INDEX__', `new_${this.#counter++}`)
    this.listTarget.insertAdjacentHTML('beforeend', markup)
  }

  remove (event) {
    event.preventDefault()
    event.currentTarget.closest('[data-bullet-editors-target="item"]').remove()
    this.compose()
  }

  focusFirst (event) {
    event.preventDefault()
    // Focus the contenteditable directly -- the host's focus() defers to Lexical and no-ops here
    this.itemTargets[0]?.querySelector('lexxy-editor [contenteditable]')?.focus()
  }

  // -- pointer drag-to-reorder --
  handleTargetConnected (handle) {
    handle.addEventListener('pointerdown', this.#onPointerDown)
  }

  #onPointerDown = (event) => {
    if (event.button !== 0) return
    const item = event.target.closest('[data-bullet-editors-target="item"]')
    if (!item) return
    event.preventDefault()
    this.draggingItem = item
    this.dropTarget = null
    item.classList.add('tw:opacity-50')
    document.addEventListener('pointermove', this.#onPointerMove)
    document.addEventListener('pointerup', this.#onPointerUp, { once: true })
  }

  #onPointerMove = (event) => {
    const item = this.itemTargets.find((row) => {
      const box = row.getBoundingClientRect()
      return event.clientY >= box.top && event.clientY <= box.bottom
    })
    if (!item) return
    const box = item.getBoundingClientRect()
    this.dropTarget = item
    this.dropAfter = event.clientY > box.top + box.height / 2
    item.parentNode.insertBefore(this.indicator, this.dropAfter ? item.nextSibling : item)
  }

  #onPointerUp = () => {
    this.#stopTracking()
    this.draggingItem.classList.remove('tw:opacity-50')
    if (this.dropTarget && this.dropTarget !== this.draggingItem) this.#reorder(this.dropTarget, this.dropAfter)
    this.draggingItem = null
    this.dropTarget = null
  }

  #stopTracking () {
    document.removeEventListener('pointermove', this.#onPointerMove)
    document.removeEventListener('pointerup', this.#onPointerUp)
    this.indicator?.remove()
  }

  // Swap editor values to match the new order; the rows (and their editors) never move.
  #reorder (target, after) {
    const editors = this.itemTargets.map((item) => item.querySelector('lexxy-editor'))
    const values = editors.map((editor) => editor?.value ?? '')
    const from = this.itemTargets.indexOf(this.draggingItem)
    let to = this.itemTargets.indexOf(target) + (after ? 1 : 0)
    if (to > from) to -= 1
    if (from === to) return

    const [moved] = values.splice(from, 1)
    values.splice(to, 0, moved)
    editors.forEach((editor, i) => { if (editor && editor.value !== values[i]) editor.value = values[i] })
    this.compose()
  }

  // Arrow so it survives being passed as an event listener
  compose = () => {
    const editors = this.itemTargets
      .map((item) => item.querySelector('lexxy-editor'))
      .filter(Boolean)
    // Editors upgrade asynchronously; bail until every one exposes a value so the first
    // paint never clobbers the server-rendered body with empties.
    if (editors.some((editor) => editor.value === undefined)) return

    const items = editors
      .map((editor) => this.#inline(editor.value))
      .filter((content) => this.#hasText(content))
      .map((content) => `<li>${content}</li>`)
    this.fieldTarget.value = items.length ? `<ul>${items.join('')}</ul>` : ''
  }

  get form () {
    return this.element.closest('form')
  }

  // Flatten the editor's block markup into inline content for one <li>. Lexxy wraps each
  // line in <p>, and Enter adds more -- left as-is they'd produce a malformed <li>...</p><p>...
  #inline (html) {
    return (html || '')
      .replace(/<p[^>]*>/gi, '')
      .replace(/<\/p>\s*/gi, ' ')
      .replace(/<br\s*\/?>/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim()
  }

  // True when real text remains once tags and entities are stripped -- skips blank bullets
  #hasText (html) {
    return html.replace(/<[^>]+>/g, '').replace(/&nbsp;/gi, ' ').trim().length > 0
  }
}
