import { Controller } from '@hotwired/stimulus'

// Drag a multiselect combobox's chips to reorder its value, and so the compared vehicles.
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
    this.#reset()
  }

  #onPointerDown = (event) => {
    if (event.button !== 0) return
    if (event.target.closest('.hw-combobox__chip__remover')) return
    this.dragging = event.target.closest('[data-hw-combobox-chip]')
    if (!this.dragging) return

    this.startX = event.clientX
    this.moved = false
    document.addEventListener('pointermove', this.#onPointerMove)
    document.addEventListener('pointerup', this.#onPointerUp, { once: true })
    // a touch gesture the browser takes over (scroll/zoom) fires pointercancel
    document.addEventListener('pointercancel', this.#reset, { once: true })
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

  #onPointerUp = () => {
    if (this.moved && this.indicator.parentNode) {
      this.indicator.parentNode.insertBefore(this.dragging, this.indicator)
      this.#syncOrder()
    }
    this.#reset()
  }

  #reset = () => {
    this.dragging?.classList.remove('tw:opacity-50')
    this.dragging = null
    document.removeEventListener('pointermove', this.#onPointerMove)
    document.removeEventListener('pointerup', this.#onPointerUp)
    document.removeEventListener('pointercancel', this.#reset)
    this.indicator.remove()
  }

  #syncOrder () {
    const hiddenField = this.element.querySelector("[data-hw-combobox-target='hiddenField']")
    const value = Array.from(this.element.querySelectorAll('[data-hw-combobox-value-param]'), (remover) => remover.dataset.hwComboboxValueParam).join(',')

    if (value === hiddenField.value) return

    hiddenField.value = value
    this.element.closest('form').requestSubmit()
  }
}
