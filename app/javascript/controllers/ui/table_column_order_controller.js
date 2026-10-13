import { Controller } from '@hotwired/stimulus'

/* global localStorage */

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
    this.applyOrder(this.storedOrder)
    this.listen('addEventListener')
  }

  disconnect () {
    this.listen('removeEventListener')
  }

  // Wired here rather than in data-action, so a table needs only the controller
  listen (method) {
    Object.entries({ dragstart: this.dragStart, dragover: this.dragOver, drop: this.drop, dragend: this.dragEnd })
      .forEach(([type, handler]) => this.element[method](type, handler))
  }

  dragStart = (event) => {
    const th = this.header(event)
    if (!th) return
    this.dragged = this.cellName(th)
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', this.dragged)
  }

  dragOver = (event) => {
    const th = this.header(event)
    if (!th || !this.dragged) return
    event.preventDefault()
    const box = th.getBoundingClientRect()
    this.dropAfter = event.clientX > box.left + box.width / 2
    if (th !== this.indicated) this.clearIndicator()
    this.indicated = th
    th.style.boxShadow = `inset ${this.dropAfter ? -2 : 2}px 0 #2563eb`
  }

  drop = (event) => {
    const th = this.header(event)
    if (!th || !this.dragged) return
    event.preventDefault()
    const target = this.cellName(th)
    if (target === this.dragged) return
    const order = this.headers.map(header => this.cellName(header)).filter(name => name !== this.dragged)
    order.splice(order.indexOf(target) + (this.dropAfter ? 1 : 0), 0, this.dragged)
    localStorage.setItem(this.storageKeyValue, JSON.stringify(order))
    this.applyOrder(order)
  }

  dragEnd = () => {
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

  get storedOrder () {
    try {
      const order = JSON.parse(localStorage.getItem(this.storageKeyValue))
      if (order === null || Array.isArray(order)) return order
    } catch {}
    localStorage.removeItem(this.storageKeyValue)
    return null
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
