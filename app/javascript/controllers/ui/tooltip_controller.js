import { Controller } from '@hotwired/stimulus'
import { computePosition, flip, shift, offset, autoUpdate } from '@floating-ui/dom'
import { claimFloatingZIndex, releaseFloatingZIndex } from 'utils/floating_z_index'

// Connects to data-controller="ui--tooltip"
//
// State model: two independent flags, OR'd together.
//   hoverActive       toggled by mouseenter/mouseleave
//   persistentActive  set by focus or a click / cleared by a press outside or
//                     focus moving to another element in the page
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
    this.pointerdownOutside = this.pointerdownOutside.bind(this)
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

  // Bound to click as well as focusin: Escape leaves focus on the trigger, so
  // no focusin fires to reopen with
  showPersistent () {
    this.persistentActive = true
    document.addEventListener('pointerdown', this.pointerdownOutside)
    this.sync()
  }

  // A focusout with a null relatedTarget is the window losing focus to another
  // program - not a dismissal
  hideOnFocusout (event) {
    if (!event.relatedTarget || this.element.contains(event.relatedTarget)) return
    this.persistentActive = false
    this.sync()
  }

  // The press rather than the click: a selection dragged out of the tooltip
  // ends in a click whose target is a common ancestor, and reads as outside
  pointerdownOutside (event) {
    if (this.element.contains(event.target)) return
    this.persistentActive = false
    this.sync()
  }

  keydownEscape (event) {
    if (event.key !== 'Escape') return
    // Focus can sit on a link inside the tooltip being hidden - the focusin
    // this fires is undone by the lines below
    if (this.element.contains(document.activeElement)) this.triggerTarget.focus()
    this.hoverActive = false
    this.persistentActive = false
    this.sync()
  }

  sync () {
    // Pointer events only while held open - always-on would swallow clicks on
    // whatever a hover-only tooltip overlaps
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
    document.removeEventListener('pointerdown', this.pointerdownOutside)
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
