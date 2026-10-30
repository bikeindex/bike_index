import { Controller } from '@hotwired/stimulus'
import { followPointer, moveByKey, startsDrag } from 'utils/drag_handle'

// Drag a multiselect combobox's chips to reorder its value, and so the compared vehicles, or move
// one a place at a time by its UI::DragHandle's arrow keys.
// Pointer events rather than native HTML5 drag, which is flaky across browsers and dead on touch
export default class extends Controller {
  connect () {
    this.element.addEventListener('pointerdown', this.#onPointerDown)
    // Slid into the target gap during a drag; pointer-events:none so it never blocks hit-testing.
    this.indicator = document.createElement('span')
    this.indicator.setAttribute('aria-hidden', 'true')
    this.indicator.style.cssText = 'width:2px;align-self:stretch;border-radius:9999px;background:var(--hw-focus-color);pointer-events:none;'
  }

  disconnect () {
    this.element.removeEventListener('pointerdown', this.#onPointerDown)
    this.stopFollowing?.()
  }

  moveByKey (event) {
    moveByKey(event, () => [...this.element.querySelectorAll('[data-hw-combobox-chip]')], (chip, target, after) => {
      target.parentNode.insertBefore(chip, after ? target.nextSibling : target)
      this.#syncOrder()
    })
  }

  // Not prevented, and a drag only once it's gone 5px, so a press on the chip still clicks
  #onPointerDown = (event) => {
    if (!startsDrag(event)) return
    if (event.target.closest('.hw-combobox__chip__remover')) return
    this.dragging = event.target.closest('[data-hw-combobox-chip]')
    if (!this.dragging) return

    this.startX = event.clientX
    this.moved = false
    this.stopFollowing = followPointer(event, { move: this.#onPointerMove, drop: this.#drop, done: this.#done })
  }

  #onPointerMove = (event) => {
    if (!this.moved) {
      if (Math.abs(event.clientX - this.startX) < 5) return
      this.moved = true
      this.dragging.classList.add('tw:opacity-50')
    }
    event.preventDefault()

    const over = document.elementFromPoint(event.clientX, event.clientY)?.closest('[data-hw-combobox-chip]')
    if (!over || over === this.dragging) return

    const { left, width } = over.getBoundingClientRect()
    const after = event.clientX > left + width / 2
    over.parentNode.insertBefore(this.indicator, after ? over.nextSibling : over)
  }

  #drop = () => {
    if (!this.moved || !this.indicator.parentNode) return
    this.indicator.parentNode.insertBefore(this.dragging, this.indicator)
    this.#syncOrder()
  }

  #done = () => {
    this.dragging?.classList.remove('tw:opacity-50')
    this.dragging = null
    this.indicator.remove()
    this.stopFollowing = null
  }

  #syncOrder () {
    const hiddenField = this.element.querySelector("[data-hw-combobox-target='hiddenField']")
    const value = Array.from(this.element.querySelectorAll('[data-hw-combobox-value-param]'), (remover) => remover.dataset.hwComboboxValueParam).join(',')

    if (value === hiddenField.value) return

    hiddenField.value = value
    this.element.closest('form').requestSubmit()
  }
}
