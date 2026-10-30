import { Controller } from '@hotwired/stimulus'
import { storedArray } from 'utils/stored_array'
import { storage } from 'utils/storage'
import { followPointer, moveByKey, startsDrag } from 'utils/drag_handle'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ui--table-column-order'
// Drag a th.hideableColumn by its UI::DragHandle to move its column, or move it a place at a time
// by the handle's arrow keys. A column is named by its *_cell class, as ui--table-column-settings
// names it. The hideable columns follow the fixed ones, so a row's are reordered by appending them.
// An order is saved only while it differs from the one the page rendered, which the reset target
// returns to. The copy target takes another table's saved order, by its data-storage-key.
// Pointer events rather than native HTML5 drag, which is dead on touch and deaf to keys
export default class extends Controller {
  static targets = ['handle', 'actions', 'reset', 'separator', 'copy']
  static values = { storageKey: String }

  connect () {
    this.defaultOrder = this.#order
    this.applyOrder(storedArray(this.storageKeyValue))
    this.#toggleActions(0)
    window.addEventListener('storage', this.#onStorage)
  }

  disconnect () {
    window.removeEventListener('storage', this.#onStorage)
    this.stopFollowing?.()
  }

  // The order the copy target copies, saved from another tab
  #onStorage = () => this.#toggleActions()

  // Reconnects each time applyOrder moves its header, which the shared listener makes harmless
  handleTargetConnected (handle) {
    handle.addEventListener('pointerdown', this.#onPointerDown)
  }

  // Past the columns showing, not the ones unchecked
  moveByKey (event) {
    moveByKey(event, () => this.headers.filter(th => th.offsetParent), (th, target, after) => this.#move(th, target, after))
  }

  #onPointerDown = (event) => {
    if (!startsDrag(event)) return
    event.preventDefault()
    this.dragged = event.target.closest('th.hideableColumn')
    this.dragged.classList.add('tw:opacity-50')
    this.scroller = this.dragged.closest('table').parentElement
    this.stopFollowing = followPointer(event, { move: this.#onPointerMove, drop: this.#drop, done: this.#done })
  }

  #onPointerMove = (event) => {
    this.pointerX = event.clientX
    this.#indicate()
    this.scrollFrame ??= window.requestAnimationFrame(this.#scroll)
  }

  // By the column under the pointer, so a finger needn't stay on the header row - within the
  // scroller, so a pointer past its edge takes the column at that edge rather than one clipped out
  #indicate () {
    const { left, right } = this.scroller.getBoundingClientRect()
    const x = Math.min(Math.max(this.pointerX, left), right - 1)
    const th = this.headers.find(header => {
      const box = header.getBoundingClientRect()
      return x >= box.left && x < box.right
    })
    if (!th) return
    const box = th.getBoundingClientRect()
    this.dropAfter = x > box.left + box.width / 2
    if (th !== this.indicated) this.clearIndicator()
    this.indicated = th
    th.style.boxShadow = `inset ${this.dropAfter ? -2 : 2}px 0 #2563eb`
  }

  // Every frame the pointer stays near an edge of the scroller, as a native drag would
  #scroll = () => {
    const { left, right } = this.scroller.getBoundingClientRect()
    const step = this.pointerX < left + 40 ? -10 : (this.pointerX > right - 40 ? 10 : 0)
    if (!step) {
      this.scrollFrame = null
      return
    }
    this.scroller.scrollLeft += step
    this.#indicate()
    this.scrollFrame = window.requestAnimationFrame(this.#scroll)
  }

  #drop = () => {
    if (this.indicated && this.indicated !== this.dragged) this.#move(this.dragged, this.indicated, this.dropAfter)
  }

  #done = () => {
    window.cancelAnimationFrame(this.scrollFrame)
    this.scrollFrame = null
    this.dragged?.classList.remove('tw:opacity-50')
    this.dragged = null
    this.clearIndicator()
    this.stopFollowing = null
  }

  #move (th, target, after) {
    const name = this.cellName(th)
    const order = this.#order.filter(other => other !== name)
    order.splice(order.indexOf(this.cellName(target)) + (after ? 1 : 0), 0, name)
    this.#reorder(order)
  }

  reset () {
    this.#reorder(this.defaultOrder)
  }

  // The order it copies can have gone in the meantime, from another tab
  copy () {
    const order = this.#copiedOrder
    order ? this.#reorder(order) : this.#toggleActions()
  }

  #reorder (order) {
    if (sameOrder(order, this.defaultOrder)) {
      storage.removeItem(this.storageKeyValue)
    } else {
      storage.setItem(this.storageKeyValue, JSON.stringify(order))
    }
    this.applyOrder(order)
    this.#toggleActions()
  }

  // The copied table's order for the columns both have, each of this one's own keeping its place
  get #copiedOrder () {
    const source = this.hasCopyTarget && storedArray(this.copyTarget.dataset.storageKey)
    if (!source) return null
    const order = this.#order
    const shared = source.filter(name => order.includes(name))
    let index = 0
    return order.map(name => shared.includes(name) ? shared[index++] : name)
  }

  // Left as they were while the row collapses, so it doesn't empty first
  #toggleActions (duration) {
    if (!this.hasActionsTarget) return
    const order = this.#order
    const moved = !sameOrder(order, this.defaultOrder)
    const copied = this.#copiedOrder
    const copyable = Boolean(copied) && !sameOrder(copied, order)
    if (!moved && !copyable) return collapse('hide', this.actionsTarget, duration)

    this.resetTarget.classList.toggle('tw:hidden!', !moved)
    this.separatorTargets.forEach(separator => separator.classList.toggle('tw:hidden!', !(moved && copyable)))
    this.copyTargets.forEach(copy => copy.classList.toggle('tw:hidden!', !copyable))
    collapse('show', this.actionsTarget, duration)
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

  get #order () {
    return this.headers.map(header => this.cellName(header))
  }

  get headers () {
    return [...this.element.querySelectorAll('th.hideableColumn')]
  }

  cellName (element) {
    return [...element.classList].find(name => name.endsWith('_cell'))
  }
}

const sameOrder = (order, other) => order.join(' ') === other.join(' ')
