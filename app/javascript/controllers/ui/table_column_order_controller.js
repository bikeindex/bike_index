import { Controller } from '@hotwired/stimulus'
import { storedArray } from 'utils/stored_array'

/* global localStorage */

// Connects to data-controller='ui--table-column-order'
// Drag a th.hideableColumn by its UI::DragHandle onto another to move its column. A column is
// named by its *_cell class, as ui--table-column-settings names it. The hideable columns follow
// the fixed ones, so a row's are reordered by appending them.
export default class extends Controller {
  static targets = ['handle']
  static values = { storageKey: String }

  connect () {
    this.applyOrder(storedArray(this.storageKeyValue))
  }

  // Pressed inside a selection of the header's text, a drag would carry the text instead
  handleTargetConnected (handle) {
    handle.draggable = true
    handle.addEventListener('mousedown', () => window.getSelection().removeAllRanges())
  }

  // Only from a handle, so dragging a header's sort link doesn't move its column
  dragStart (event) {
    if (!this.handleTargets.includes(event.target)) return
    const th = this.header(event)
    this.dragged = this.cellName(th)
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', this.dragged)
    event.dataTransfer.setDragImage(th, 0, 0)
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
    localStorage.setItem(this.storageKeyValue, JSON.stringify(order))
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
