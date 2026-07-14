import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='registrations--new--combobox-display'
//
// Renders the selected combobox option with its parenthetical in muted text.
// An <input> can't render two-tone text, so a mirror overlay covers the input
// whenever it isn't focused for filtering.
export default class extends Controller {
  static targets = ['overlay']

  connect () {
    this.input = this.element.querySelector('.hw-combobox__input')
    this.input.addEventListener('focus', this.hide)
    this.input.addEventListener('blur', this.show)
    this.element.addEventListener('hw-combobox:selection', this.show)
    window.addEventListener('resize', this.reposition)
    this.show()
  }

  disconnect () {
    this.input.removeEventListener('focus', this.hide)
    this.input.removeEventListener('blur', this.show)
    this.element.removeEventListener('hw-combobox:selection', this.show)
    window.removeEventListener('resize', this.reposition)
  }

  show = () => {
    if (document.activeElement === this.input || this.input.value === '') return

    const [base, parens] = this.input.value.split(' (', 2)
    this.overlayTarget.replaceChildren(document.createTextNode(base))
    if (parens) {
      this.overlayTarget.append(' ')
      const muted = document.createElement('span')
      muted.className = 'tw:text-[#9a9aa2] tw:dark:text-gray-500'
      muted.textContent = `(${parens}`
      this.overlayTarget.append(muted)
    }
    this.reposition()
    this.input.style.color = 'transparent'
    this.overlayTarget.classList.remove('tw:hidden')
  }

  hide = () => {
    this.input.style.color = ''
    this.overlayTarget.classList.add('tw:hidden')
  }

  reposition = () => {
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
