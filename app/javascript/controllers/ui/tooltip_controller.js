import { Controller } from '@hotwired/stimulus'
import { computePosition, flip, shift, offset, arrow, hide, autoUpdate } from '@floating-ui/dom'
import { claimFloatingZIndex, releaseFloatingZIndex } from 'utils/floating_z_index'

// Connects to data-controller="ui--tooltip"
//
// Shown as a manual popover, in the top layer: an ancestor's opacity - a disabled
// control's - its overflow clipping and its stacking context don't reach it there.
// The top layer stacks in the order shown, so raising one shows it again. A
// browser without popovers (Safari before 17) raises it by z-index instead.
//
// State model: two independent flags, OR'd together.
//   hoverActive       set by mouseenter / cleared by mouseleave, unless the pointer
//                     is crossing the gap onto the tooltip - then once it strays
//   persistentActive  set by focus or a click / cleared by a press outside or
//                     focus moving to another element in the page
// The tooltip is visible whenever either flag is true.

// Keyed by placement side: the tooltip edge the arrow sits on, and the
// arrow's two outward borders (top right bottom left)
const ARROW_SIDES = {
  top: { edge: 'bottom', borderWidth: '0 1px 1px 0' },
  right: { edge: 'left', borderWidth: '0 0 1px 1px' },
  bottom: { edge: 'top', borderWidth: '1px 0 0 1px' },
  left: { edge: 'right', borderWidth: '1px 1px 0 0' }
}

const POPOVER = 'popover' in window.HTMLElement.prototype
const STRATEGY = POPOVER ? 'fixed' : 'absolute'

export default class extends Controller {
  static targets = ['trigger', 'tooltip', 'arrow']
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
    this.pointermoveBetween = this.pointermoveBetween.bind(this)
  }

  // A popover's UA overflow clips the arrow hanging off its edge
  tooltipTargetConnected (tooltip) {
    if (!POPOVER) return
    tooltip.popover = 'manual'
    tooltip.style.overflow = 'visible'
  }

  disconnect () {
    this.close()
  }

  // The one under the pointer goes on top, though another was opened since
  showOnHover () {
    document.removeEventListener('pointermove', this.pointermoveBetween)
    this.hoverActive = true
    if (this.isOpen) this.#raise()
    this.sync()
  }

  hideOnHover (event) {
    if (this.isOpen && this.#between(event)) document.addEventListener('pointermove', this.pointermoveBetween)
    else this.#endHover()
  }

  pointermoveBetween (event) {
    if (!this.#between(event)) this.#endHover()
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
    if (this.hoverActive || this.persistentActive) this.open()
    else this.close()
  }

  open () {
    if (this.isOpen) return
    this.isOpen = true
    this.tooltipTarget.classList.remove('tw:hidden')
    this.#raise()
    document.addEventListener('keydown', this.keydownEscape)
    this.cleanup = autoUpdate(this.triggerTarget, this.tooltipTarget, () => this.updatePosition())
  }

  close () {
    if (!this.isOpen) return
    this.isOpen = false
    if (!POPOVER) releaseFloatingZIndex(this.tooltipTarget)
    else if (this.tooltipTarget.matches(':popover-open')) this.tooltipTarget.hidePopover()
    this.tooltipTarget.classList.add('tw:hidden')
    document.removeEventListener('pointerdown', this.pointerdownOutside)
    document.removeEventListener('keydown', this.keydownEscape)
    document.removeEventListener('pointermove', this.pointermoveBetween)
    if (this.cleanup) {
      this.cleanup()
      this.cleanup = null
    }
  }

  #endHover () {
    document.removeEventListener('pointermove', this.pointermoveBetween)
    this.hoverActive = false
    this.sync()
  }

  #between ({ clientX, clientY }) {
    const [trigger, tooltip] = [this.triggerTarget, this.tooltipTarget].map((element) => element.getBoundingClientRect())
    return clientX >= Math.min(trigger.left, tooltip.left) && clientX <= Math.max(trigger.right, tooltip.right) &&
      clientY >= Math.min(trigger.top, tooltip.top) && clientY <= Math.max(trigger.bottom, tooltip.bottom)
  }

  #raise () {
    if (!POPOVER) return claimFloatingZIndex(this.tooltipTarget)
    this.tooltipTarget.hidePopover()
    this.tooltipTarget.showPopover()
  }

  async updatePosition () {
    const { x, y, placement, middlewareData } = await computePosition(this.triggerTarget, this.tooltipTarget, {
      placement: this.placementValue,
      strategy: STRATEGY,
      middleware: [offset(8), flip(), shift({ padding: 4 }), arrow({ element: this.arrowTarget, padding: 4 }), hide()]
    })
    // in the top layer, no container clips it once its trigger scrolls out of view
    Object.assign(this.tooltipTarget.style, {
      left: `${x}px`,
      top: `${y}px`,
      position: STRATEGY,
      visibility: middlewareData.hide.referenceHidden ? 'hidden' : ''
    })

    const { edge, borderWidth } = ARROW_SIDES[placement.split('-')[0]]
    const { x: arrowX, y: arrowY } = middlewareData.arrow
    // -5px: half the 8px arrow, plus the tooltip's 1px border
    Object.assign(this.arrowTarget.style, {
      left: arrowX != null ? `${arrowX}px` : '',
      top: arrowY != null ? `${arrowY}px` : '',
      right: '',
      bottom: '',
      [edge]: '-5px',
      borderWidth
    })
  }
}
