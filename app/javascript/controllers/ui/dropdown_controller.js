import { Controller } from '@hotwired/stimulus'
import { computePosition, flip, shift, offset } from '@floating-ui/dom'

let zCounter = 50

// Connects to data-controller="ui--dropdown"
export default class extends Controller {
  static targets = ['menu', 'button']
  static values = {
    open: Boolean,
    placement: { type: String, default: 'bottom-end' }
  }

  connect () {
    this.clickOutside = this.clickOutside.bind(this)
    this.handleEscape = this.handleEscape.bind(this)
    this.handleResize = this.handleResize.bind(this)
  }

  disconnect () {
    this.close()
  }

  toggle (event) {
    event.stopPropagation()
    this.openValue = !this.openValue
  }

  openValueChanged () {
    if (this.openValue) {
      this.open()
    } else {
      this.close()
    }
  }

  async open () {
    this.menuTarget.classList.remove('tw:hidden')
    this.menuTarget.style.zIndex = ++zCounter
    this.buttonTarget.setAttribute('aria-expanded', 'true')
    await this.updatePosition()
    this.addEventListeners()
  }

  close () {
    this.menuTarget.classList.add('tw:hidden')
    this.buttonTarget.setAttribute('aria-expanded', 'false')
    this.removeEventListeners()
  }

  addEventListeners () {
    document.addEventListener('click', this.clickOutside)
    document.addEventListener('keydown', this.handleEscape)
    window.addEventListener('resize', this.handleResize)
  }

  removeEventListeners () {
    document.removeEventListener('click', this.clickOutside)
    document.removeEventListener('keydown', this.handleEscape)
    window.removeEventListener('resize', this.handleResize)
  }

  async updatePosition () {
    const { x, y } = await computePosition(this.buttonTarget, this.menuTarget, {
      placement: this.placementValue,
      middleware: [
        offset(4),
        flip(),
        shift({ padding: 8, boundary: 'viewport' })
      ]
    })

    Object.assign(this.menuTarget.style, {
      left: `${x}px`,
      top: `${y}px`,
      position: 'absolute',
      right: 'auto',
      width: 'auto',
      maxWidth: 'auto'
    })
  }

  clickOutside (event) {
    if (!this.element.contains(event.target)) {
      this.openValue = false
    }
  }

  handleEscape (event) {
    if (event.key === 'Escape') {
      this.openValue = false
      this.buttonTarget.focus()
    }
  }

  handleResize () {
    if (this.openValue) {
      this.updatePosition()
    }
  }
}
