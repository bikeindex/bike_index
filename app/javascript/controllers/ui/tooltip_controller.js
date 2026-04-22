import { Controller } from '@hotwired/stimulus'
import { computePosition, flip, shift, offset, autoUpdate } from '@floating-ui/dom'

let topZIndex = 50

// Connects to data-controller="ui--tooltip"
//
// State model: two independent flags, OR'd together.
//   hoverActive       toggled by mouseenter/mouseleave
//   persistentActive  toggled by focus / cleared by focusout or click-outside
// The tooltip is visible whenever either flag is true.
export default class extends Controller {
  static targets = ['trigger', 'tooltip']
  static values = {
    placement: { type: String, default: 'top' }
  }

  initialize () {
    this.hoverActive = false
    this.persistentActive = false
  }

  connect () {
    this.clickOutside = this.clickOutside.bind(this)
  }

  disconnect () {
    this.close()
  }

  showOnHover () {
    this.hoverActive = true
    this.sync()
  }

  hideOnHover () {
    this.hoverActive = false
    this.sync()
  }

  showOnFocus () {
    this.persistentActive = true
    document.addEventListener('click', this.clickOutside)
    this.sync()
  }

  hideOnFocusout () {
    this.persistentActive = false
    this.sync()
  }

  clickOutside (event) {
    if (this.element.contains(event.target)) return
    this.persistentActive = false
    this.sync()
  }

  sync () {
    if (this.hoverActive || this.persistentActive) this.open()
    else this.close()
  }

  open () {
    if (this.isOpen) return
    this.isOpen = true
    topZIndex += 1
    this.tooltipTarget.style.zIndex = topZIndex
    this.tooltipTarget.classList.remove('tw:hidden')
    this.cleanup = autoUpdate(this.triggerTarget, this.tooltipTarget, () => this.updatePosition())
  }

  close () {
    if (!this.isOpen) return
    this.isOpen = false
    this.tooltipTarget.classList.add('tw:hidden')
    document.removeEventListener('click', this.clickOutside)
    if (this.cleanup) {
      this.cleanup()
      this.cleanup = null
    }
  }

  async updatePosition () {
    const { x, y } = await computePosition(this.triggerTarget, this.tooltipTarget, {
      placement: this.placementValue,
      middleware: [offset(6), flip(), shift({ padding: 4 })]
    })
    Object.assign(this.tooltipTarget.style, {
      left: `${x}px`,
      top: `${y}px`,
      position: 'absolute'
    })
  }
}
