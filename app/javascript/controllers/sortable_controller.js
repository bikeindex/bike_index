import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='sortable'
// Drag-and-drop reordering of [data-sortable-target=item] rows. On drop, PATCHes the moved row's
// new position to its own data-url endpoint.
export default class extends Controller {
  static targets = ['item']

  connect () {
    this.dragging = null
    this.itemTargets.forEach((item) => this.bind(item))
  }

  bind (item) {
    item.addEventListener('dragstart', () => {
      this.dragging = item
      item.classList.add('tw:opacity-50')
    })
    item.addEventListener('dragend', () => {
      item.classList.remove('tw:opacity-50')
      const moved = this.dragging
      this.dragging = null
      this.persist(moved)
    })
    item.addEventListener('dragover', (event) => {
      event.preventDefault()
      if (!this.dragging) return
      const after = this.afterElement(event.clientY)
      if (after == null) this.element.appendChild(this.dragging)
      else this.element.insertBefore(this.dragging, after)
    })
  }

  afterElement (y) {
    const others = this.itemTargets.filter((item) => item !== this.dragging)
    return others.reduce((closest, item) => {
      const box = item.getBoundingClientRect()
      const offset = y - box.top - box.height / 2
      if (offset < 0 && offset > closest.offset) return { offset, element: item }
      return closest
    }, { offset: Number.NEGATIVE_INFINITY, element: null }).element
  }

  persist (item) {
    const position = this.itemTargets.indexOf(item)
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(item.dataset.url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': token },
      body: JSON.stringify({ position })
    })
  }
}
