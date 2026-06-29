import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='sortable'
// Drag-and-drop reordering of [data-sortable-target=item] rows, grabbed by their
// [data-sortable-target=handle] grip. A thin bar shows where the row will land; on drop
// the row is moved there and (when it has data-url) its new position is PATCHed.
// Subclasses override reorder() when the rows can't be relocated directly.
export default class extends Controller {
  static targets = ['item', 'handle']

  connect () {
    this.draggingItem = null
    // Slid into the target gap during a drag -- decoupled from the rows so it works even
    // when the rows themselves can't move (e.g. they hold editors that crash on relocation).
    this.indicator = document.createElement('div')
    this.indicator.setAttribute('aria-hidden', 'true')
    this.indicator.style.cssText = 'height:2px;border-radius:9999px;background:#2563eb;'
  }

  handleTargetConnected (handle) {
    const item = handle.closest(this.#itemSelector)
    handle.addEventListener('dragstart', (event) => {
      this.draggingItem = item
      event.dataTransfer.effectAllowed = 'move'
      event.dataTransfer.setData('text/plain', '')
      // Defer dimming so the full row is captured as the drag image first
      setTimeout(() => item.classList.add('tw:opacity-50'), 0)
    })
    handle.addEventListener('dragend', () => {
      item.classList.remove('tw:opacity-50')
      this.draggingItem = null
      this.indicator.remove()
    })
  }

  itemTargetConnected (item) {
    item.addEventListener('dragover', (event) => {
      if (!this.draggingItem) return
      event.preventDefault()
      event.dataTransfer.dropEffect = 'move'
      item.parentNode.insertBefore(this.indicator, this.#after(item, event.clientY) ? item.nextSibling : item)
    })
    item.addEventListener('drop', (event) => {
      if (!this.draggingItem || item === this.draggingItem) return
      event.preventDefault()
      this.indicator.remove()
      this.reorder(item, this.#after(item, event.clientY))
    })
  }

  // Default: move the dragged row next to the target, then persist its new position.
  reorder (target, after) {
    target.parentNode.insertBefore(this.draggingItem, after ? target.nextSibling : target)
    this.persist(this.draggingItem)
  }

  persist (item) {
    if (!item.dataset.url) return
    const position = this.itemTargets.indexOf(item)
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(item.dataset.url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': token },
      body: JSON.stringify({ position })
    })
  }

  #after (item, clientY) {
    const box = item.getBoundingClientRect()
    return clientY > box.top + box.height / 2
  }

  get #itemSelector () {
    return `[data-${this.identifier}-target="item"]`
  }
}
