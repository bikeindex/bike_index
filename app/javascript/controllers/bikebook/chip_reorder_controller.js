import { Controller } from '@hotwired/stimulus'

// Pointer drag-to-reorder for multiselect combobox chips (native HTML5 drag is
// flaky across browsers and dead on touch). The dragged chip dims in place while a
// thin bar marks where it will land; on release it moves there, the hidden field's
// comma-joined value is rewritten to match, and the form re-submits — reordering
// the compared-model grid.
export default class extends Controller {
  connect () {
    this.element.addEventListener('pointerdown', this.#onPointerDown)
    // Slid into the target gap during a drag; pointer-events:none so it never blocks hit-testing.
    this.indicator = document.createElement('span')
    this.indicator.setAttribute('aria-hidden', 'true')
    this.indicator.style.cssText = 'width:2px;align-self:stretch;border-radius:9999px;background:var(--color-blueprint,#2563eb);pointer-events:none;'
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
    document.addEventListener('pointercancel', this.#onPointerCancel, { once: true })
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

  // The browser can hijack a touch gesture (scroll/zoom) and fire pointercancel; abort cleanly.
  #onPointerCancel = () => {
    this.#reset()
  }

  #reset () {
    this.dragging?.classList.remove('tw:opacity-50')
    this.dragging = null
    document.removeEventListener('pointermove', this.#onPointerMove)
    document.removeEventListener('pointerup', this.#onPointerUp)
    document.removeEventListener('pointercancel', this.#onPointerCancel)
    this.indicator?.remove()
  }

  #syncOrder () {
    const hiddenField = this.element.querySelector("[data-hw-combobox-target='hiddenField']")
    if (!hiddenField) return

    const value = Array.from(this.element.querySelectorAll('[data-hw-combobox-chip]'))
      .map(chip => chip.querySelector('[data-hw-combobox-value-param]')?.dataset.hwComboboxValueParam)
      .filter(Boolean)
      .join(',')

    if (value === hiddenField.value) return

    hiddenField.value = value
    this.element.closest('form')?.requestSubmit()
  }
}
