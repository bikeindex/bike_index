import { Controller } from '@hotwired/stimulus'
import { storedArray } from 'utils/stored_array'
import { storage } from 'utils/storage'

// Connects to data-controller='ui--table-column-order'
// Drag a th.hideableColumn onto another to move its column. A column is named by its *_cell
// class, as ui--column-settings names it. The hideable columns follow the fixed ones, so a
// row's are reordered by appending them.
export default class extends Controller {
  static values = { storageKey: String }

  connect () {
    this.headers.forEach(th => {
      th.draggable = true
      th.style.cursor = 'grab'
    })
    this.applyOrder(storedArray(this.storageKeyValue))
  }

  dragStart (event) {
    const th = this.header(event)
    if (!th) return
    this.dragged = this.cellName(th)
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', this.dragged)
  }

  dragOver (event) {
    const th = this.header(event)
    if (!th || !this.dragged) return
    event.preventDefault()
    const box = th.getBoundingClientRect()
    this.dropAfter = event.clientX > box.left + box.width / 2
    if (th !== this.indicated) this.clearIndicator()
    this.indicated = th
    th.style.boxShadow = `inset ${this.dropAfter ? -2 : 2}px 0 #2563eb`
  }

  drop (event) {
    const th = this.header(event)
    if (!th || !this.dragged) return
    event.preventDefault()
    const target = this.cellName(th)
    if (target === this.dragged) return
    const order = this.headers.map(header => this.cellName(header)).filter(name => name !== this.dragged)
    order.splice(order.indexOf(target) + (this.dropAfter ? 1 : 0), 0, this.dragged)
    storage.setItem(this.storageKeyValue, JSON.stringify(order))
    this.applyOrder(order)
  }

  dragEnd () {
    this.dragged = null
    this.clearIndicator()
  }

  clearIndicator () {
    if (this.indicated) this.indicated.style.boxShadow = ''
    this.indicated = null
  }

  applyOrder (order) {
    if (!order) return
    const position = cell => {
      const index = order.indexOf(this.cellName(cell))
      return index === -1 ? order.length : index
    }
    this.element.querySelectorAll('tr').forEach(row => {
      [...row.querySelectorAll(':scope > .hideableColumn')]
        .sort((a, b) => position(a) - position(b))
        .forEach(cell => row.appendChild(cell))
    })
    window.dispatchEvent(new Event('ui-table:refresh'))
  }

  get headers () {
    return [...this.element.querySelectorAll('th.hideableColumn')]
  }

  header (event) {
    return event.target.closest?.('th.hideableColumn')
  }

  cellName (element) {
    return [...element.classList].find(name => name.endsWith('_cell'))
  }
}
