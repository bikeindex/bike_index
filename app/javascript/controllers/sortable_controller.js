import { Controller } from '@hotwired/stimulus'
import Sortable from 'sortablejs'

// Connects to data-controller='sortable'
// Drag-to-reorder via SortableJS, grabbed by the [data-sortable-target=handle] grip.
// On drop the moved row's new position is PATCHed to its own data-url endpoint.
export default class extends Controller {
  connect () {
    this.sortable = Sortable.create(this.element, {
      handle: '[data-sortable-target="handle"]',
      animation: 150,
      onEnd: (event) => this.#persist(event)
    })
  }

  disconnect () {
    this.sortable?.destroy()
  }

  #persist (event) {
    const item = event.item
    if (!item.dataset.url || event.oldIndex === event.newIndex) return
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(item.dataset.url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': token },
      body: JSON.stringify({ position: event.newIndex })
    })
  }
}
