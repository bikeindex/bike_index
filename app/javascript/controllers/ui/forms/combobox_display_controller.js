import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--combobox-display'
// (rendered by UI::Forms::Combobox rich_display:)
//
// Renders the selected combobox option with its parenthetical in muted text.
// An <input> can't render two-tone text, so a mirror overlay covers the input
// whenever it isn't focused for filtering. The overlay clones the selected
// option's listbox content, so the two-tone formatting has a single source.
export default class extends Controller {
  static targets = ['overlay']

  connect () {
    this.input = this.element.querySelector('.hw-combobox__input')
    this.input.addEventListener('focus', this.hide)
    this.input.addEventListener('blur', this.show)
    this.element.addEventListener('hw-combobox:selection', this.show)
    window.addEventListener('resize', this.onResize)
    this.show()
  }

  disconnect () {
    this.input.removeEventListener('focus', this.hide)
    this.input.removeEventListener('blur', this.show)
    this.element.removeEventListener('hw-combobox:selection', this.show)
    window.removeEventListener('resize', this.onResize)
  }

  show = () => {
    if (document.activeElement === this.input) return

    const selectedOption = this.selectedOption()
    if (!selectedOption) { this.hide(); return }

    this.overlayTarget.innerHTML = selectedOption.innerHTML
    this.reposition()
    this.input.style.color = 'transparent'
    this.overlayTarget.classList.remove('tw:hidden')
  }

  hide = () => {
    this.input.style.color = ''
    this.overlayTarget.classList.add('tw:hidden')
  }

  onResize = () => {
    if (this.overlayTarget.classList.contains('tw:hidden')) return

    this.reposition()
  }

  selectedOption () {
    const value = this.element.querySelector('input[type="hidden"]')?.value
    if (!value) return null

    return this.element.querySelector(`[role="option"][data-value="${value}"]`)
  }

  reposition () {
    const inputRect = this.input.getBoundingClientRect()
    const wrapperRect = this.element.getBoundingClientRect()
    const computed = window.getComputedStyle(this.input)
    Object.assign(this.overlayTarget.style, {
      top: `${inputRect.top - wrapperRect.top}px`,
      left: `${inputRect.left - wrapperRect.left}px`,
      width: `${inputRect.width}px`,
      height: `${inputRect.height}px`,
      font: computed.font,
      paddingLeft: computed.paddingLeft,
      paddingRight: computed.paddingRight,
      paddingTop: computed.paddingTop,
      paddingBottom: computed.paddingBottom
    })
  }
}
