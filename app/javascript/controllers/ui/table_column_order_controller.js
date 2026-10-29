import { Controller } from '@hotwired/stimulus'
import { storedArray } from 'utils/stored_array'
import { storage } from 'utils/storage'
import { moveByKey } from 'utils/drag_handle'

// Connects to data-controller='ui--table-column-order'
// Drag a th.hideableColumn by its UI::DragHandle to move its column, or move it a place at a time
// by the handle's arrow keys. A column is named by its *_cell class, as ui--table-column-settings
// names it. The hideable columns follow the fixed ones, so a row's are reordered by appending them.
// Pointer events rather than native HTML5 drag, which is dead on touch and deaf to keys
export default class extends Controller {
  static targets = ['handle']
  static values = { storageKey: String }

  connect () {
    this.applyOrder(storedArray(this.storageKeyValue))
  }

  disconnect () {
    this.#reset()
  }

  // Reconnects each time applyOrder moves its header, which the shared listener makes harmless
  handleTargetConnected (handle) {
    handle.addEventListener('pointerdown', this.#onPointerDown)
  }

  // Past the columns showing, not the ones unchecked
  moveByKey (event) {
    moveByKey(event, () => this.headers.filter(th => th.offsetParent), (th, target, after) => this.#move(th, target, after))
  }

  #onPointerDown = (event) => {
    if (event.button !== 0) return
    event.preventDefault()
    this.dragged = event.target.closest('th.hideableColumn')
    this.dragged.classList.add('tw:opacity-50')
    document.addEventListener('pointermove', this.#onPointerMove)
    document.addEventListener('pointerup', this.#onPointerUp, { once: true })
    // a touch gesture the browser takes over (scroll/zoom) fires pointercancel
    document.addEventListener('pointercancel', this.#reset, { once: true })
  }

  // By the column under the pointer, so a finger needn't stay on the header row
  #onPointerMove = (event) => {
    this.#scrollToward(event.clientX)
    const th = this.headers.find(header => {
      const { left, right } = header.getBoundingClientRect()
      return event.clientX >= left && event.clientX < right
    })
    if (!th) return
    const box = th.getBoundingClientRect()
    this.dropAfter = event.clientX > box.left + box.width / 2
    if (th !== this.indicated) this.clearIndicator()
    this.indicated = th
    th.style.boxShadow = `inset ${this.dropAfter ? -2 : 2}px 0 #2563eb`
  }

  #onPointerUp = () => {
    const { dragged, indicated, dropAfter } = this
    this.#reset()
    if (indicated && indicated !== dragged) this.#move(dragged, indicated, dropAfter)
  }

  #reset = () => {
    this.dragged?.classList.remove('tw:opacity-50')
    this.dragged = null
    this.clearIndicator()
    document.removeEventListener('pointermove', this.#onPointerMove)
    document.removeEventListener('pointerup', this.#onPointerUp)
    document.removeEventListener('pointercancel', this.#reset)
  }

  // Near an edge of the table's scroller, as a native drag would
  #scrollToward (clientX) {
    const scroller = this.dragged.closest('table').parentElement
    const { left, right } = scroller.getBoundingClientRect()
    if (clientX < left + 40) scroller.scrollLeft -= 20
    if (clientX > right - 40) scroller.scrollLeft += 20
  }

  #move (th, target, after) {
    const name = this.cellName(th)
    const order = this.headers.map(header => this.cellName(header)).filter(other => other !== name)
    order.splice(order.indexOf(this.cellName(target)) + (after ? 1 : 0), 0, name)
    storage.setItem(this.storageKeyValue, JSON.stringify(order))
    this.applyOrder(order)
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

  cellName (element) {
    return [...element.classList].find(name => name.endsWith('_cell'))
  }
}
