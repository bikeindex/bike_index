import { Controller } from '@hotwired/stimulus'
import { computePosition, flip, shift, offset, autoUpdate } from '@floating-ui/dom'
import { claimFloatingZIndex, releaseFloatingZIndex } from 'utils/floating_z_index'

// Connects to data-controller="ui--tooltip"
//
// State model: two independent flags, OR'd together.
//   hoverActive       toggled by mouseenter/mouseleave
//   persistentActive  toggled by focus / cleared by a click outside or focus moving
//                     to another element in the page
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
    this.keydownEscape = this.keydownEscape.bind(this)
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

  // Only focus landing on another element in the page dismisses. A focusout with
  // nowhere to go is the browser window losing focus (the rider switched program)
  // or a click on the tooltip itself - neither means they're done with it.
  hideOnFocusout (event) {
    if (!event.relatedTarget || this.element.contains(event.relatedTarget)) return
    this.persistentActive = false
    this.sync()
  }

  clickOutside (event) {
    if (this.element.contains(event.target)) return
    this.persistentActive = false
    this.sync()
  }

  keydownEscape (event) {
    if (event.key !== 'Escape') return
    this.hoverActive = false
    this.persistentActive = false
    this.sync()
  }

  sync () {
    // Only a held-open tooltip takes pointer events, so its text can be clicked
    // and selected; a hover-only one stays transparent to the mouse.
    this.tooltipTarget.classList.toggle('tw:pointer-events-none', !this.persistentActive)
    if (this.hoverActive || this.persistentActive) this.open()
    else this.close()
  }

  open () {
    if (this.isOpen) return
    this.isOpen = true
    this.tooltipTarget.style.zIndex = claimFloatingZIndex(this.tooltipTarget)
    this.tooltipTarget.classList.remove('tw:hidden')
    document.addEventListener('keydown', this.keydownEscape)
    this.cleanup = autoUpdate(this.triggerTarget, this.tooltipTarget, () => this.updatePosition())
  }

  close () {
    if (!this.isOpen) return
    this.isOpen = false
    releaseFloatingZIndex(this.tooltipTarget)
    this.tooltipTarget.classList.add('tw:hidden')
    document.removeEventListener('click', this.clickOutside)
    document.removeEventListener('keydown', this.keydownEscape)
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
