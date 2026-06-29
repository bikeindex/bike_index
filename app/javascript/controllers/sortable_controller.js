import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='sortable'
// Pointer drag-to-reorder of [data-sortable-target=item] rows, grabbed by their
// [data-sortable-target=handle] grip. A thin bar shows where the row will land; on release
// the row is moved there and (when it has data-url) its new position is PATCHed.
// Pointer events -- not native HTML5 draggable -- so a rich-text editor inside a row can't
// swallow the drag and there is no native snap-back animation. Subclasses override reorder().
export default class extends Controller {
  static targets = ['item', 'handle']

  connect () {
    this.draggingItem = null
    this.dropTarget = null
    this.dropAfter = false
    // Slid into the target gap during a drag; pointer-events:none so it never blocks hit-testing.
    this.indicator = document.createElement('div')
    this.indicator.setAttribute('aria-hidden', 'true')
    this.indicator.style.cssText = 'height:2px;border-radius:9999px;background:#2563eb;pointer-events:none;'
  }

  disconnect () {
    this.#stopTracking()
  }

  handleTargetConnected (handle) {
    handle.addEventListener('pointerdown', this.#onPointerDown)
  }

  #onPointerDown = (event) => {
    if (event.button !== 0) return
    const item = event.target.closest(this.#itemSelector)
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
    this.dropTarget = item
    this.dropAfter = this.#after(item, event.clientY)
    item.parentNode.insertBefore(this.indicator, this.dropAfter ? item.nextSibling : item)
  }

  #onPointerUp = () => {
    this.#stopTracking()
    this.draggingItem.classList.remove('tw:opacity-50')
    if (this.dropTarget && this.dropTarget !== this.draggingItem) {
      this.reorder(this.dropTarget, this.dropAfter)
    }
    this.draggingItem = null
    this.dropTarget = null
  }

  #stopTracking () {
    document.removeEventListener('pointermove', this.#onPointerMove)
    document.removeEventListener('pointerup', this.#onPointerUp)
    this.indicator.remove()
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
