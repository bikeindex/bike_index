import Sortable from './sortable_controller'

// Connects to data-controller='bullet-editors'
// The page model stores its bullets as a single `body` HTML string (a <ul> of <li>s).
// These per-bullet editors are a frontend convenience: we recombine them into the hidden
// body field on change and submit. Reordering reuses the sortable drag + drop-indicator,
// but swaps editor *content* instead of moving rows -- relocating a lexxy editor crashes it.
export default class extends Sortable {
  static targets = ['field', 'list', 'template']

  #counter = 0

  connect () {
    super.connect()
    this.element.addEventListener('lexxy:change', this.compose)
    this.form?.addEventListener('submit', this.compose)
  }

  disconnect () {
    super.disconnect()
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
    event.currentTarget.closest('[data-bullet-editors-target="item"]').remove()
    this.compose()
  }

  focusFirst (event) {
    event.preventDefault()
    // Focus the contenteditable directly -- the host's focus() defers to Lexical and no-ops here
    this.itemTargets[0]?.querySelector('lexxy-editor [contenteditable]')?.focus()
  }

  // Swap editor content instead of moving rows: relocating a lexxy editor fires its
  // disconnect/connect callbacks, which crash it mid-drag.
  reorder (target, after) {
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
