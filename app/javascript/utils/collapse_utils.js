// collapse-utils.js
// Utility class for handling element collapse animations

/**
 * CollapseUtils class providing element collapse/expand functionality
 */
export class CollapseUtils {
  /**
   * Handle collapsing or showing elements with animation
   * @param {string} action - 'show', 'hide', or 'toggle'
   * @param {HTMLElement|HTMLElement[]} element - The element(s) to manipulate
   * @param {number} duration - Animation duration in milliseconds
   * @param {string} direction - 'vertical' (height) or 'horizontal' (width)
   */
  static collapse (action, element, duration, direction = 'vertical') {
    if (!element) {
      console.warn('Cannot collapse undefined or null element')
      return
    }

    // Handle arrays of elements
    if (Array.isArray(element)) {
      element.forEach(el => this.collapse(action, el, duration, direction))
      return
    }

    if (action === 'show') {
      this.show(element, duration, direction)
    } else if (action === 'hide') {
      this.hide(element, duration, direction)
    } else if (action === 'toggle') {
      this.toggle(element, duration, direction)
    } else {
      console.warn(`Invalid CollapseUtils action: ${action}. must be one of: 'show', 'hide', 'toggle'`)
    }
  }

  // The measured dimension, the styles to animate, and the collapse scale class
  // for the axis. Horizontal drives flex-basis too, since a flex-row item is
  // sized by its basis rather than its width.
  static axis (direction) {
    return direction === 'horizontal'
      ? { dimension: 'width', styles: ['width', 'flexBasis'], scale: 'tw:scale-x-0' }
      : { dimension: 'height', styles: ['height'], scale: 'tw:scale-y-0' }
  }

  // The element's natural rendered size along the axis (flex-aware, unlike
  // scrollWidth/scrollHeight, so a shrunk flex item animates to its real size).
  static naturalSize (element, dimension) {
    return element.getBoundingClientRect()[dimension]
  }

  static setSize (element, styles, value) {
    styles.forEach((style) => { element.style[style] = value })
  }

  // Reading a layout property forces a synchronous reflow, committing pending
  // style changes so the following change animates from them.
  static reflow (element) {
    return element.offsetWidth
  }

  /**
   * Toggle element visibility
   * @param {HTMLElement} element - The element to toggle
   * @param {number} duration - Animation duration in milliseconds
   * @param {string} direction - 'vertical' (height) or 'horizontal' (width)
   */
  static toggle (element, duration, direction = 'vertical') {
    if (!element) return

    const isHidden = element.classList.contains('tw:hidden!') || element.classList.contains('tw:hidden')
    this.collapse(isHidden ? 'show' : 'hide', element, duration, direction)
  }

  /**
   * Show/uncollapse an element with animation
   * @param {HTMLElement} element - The element to uncollapse
   * @param {number} duration - Animation duration in milliseconds
   * @param {string} direction - 'vertical' (height) or 'horizontal' (width)
   */
  static show (element, duration, direction = 'vertical') {
    // Cancel any in-flight hide() finalizer so it doesn't stamp tw:hidden! on us.
    this._cancelFinalizer(element)
    const { dimension, styles, scale } = this.axis(direction)
    // Bail if already fully shown — but isVisible alone isn't enough: a hide()
    // mid-transition still has display:block/visibility:visible until its finalizer
    // adds tw:hidden!, yet the scale class means the element is collapsed to 0.
    if (this.isVisible(element) && !element.classList.contains(scale)) return
    // Remove the hidden
    element.classList.remove('tw:hidden!', 'tw:hidden')
    // Measure the natural size while visible, before collapsing to 0.
    const target = this.naturalSize(element, dimension)
    // First, ensure the hidden attributes are set
    element.classList.add(scale)
    this.setSize(element, styles, 0)
    // Always add transition classes (moving toward a more generalizable collapse method)
    element.classList.add('tw:transition-all', `tw:duration-${duration}`)
    // Remove things that transition to hide the element
    element.classList.remove(scale)
    // Force a reflow so the browser commits the 0 size before transitioning.
    this.reflow(element)
    // Set the element's size to its natural size to expand it
    this.setSize(element, styles, `${target}px`)

    // After transition is complete, remove explicit size (clean up afterward)
    element._collapseFinalizer = setTimeout(() => {
      this.setSize(element, styles, '')
      element._collapseFinalizer = null
    }, duration)
  }

  /**
   * Hide/collapse an element with animation
   * @param {HTMLElement} element - The element to collapse
   * @param {number} duration - Animation duration in milliseconds
   * @param {string} direction - 'vertical' (height) or 'horizontal' (width)
   */
  static hide (element, duration, direction = 'vertical') {
    this._cancelFinalizer(element)
    // Return early if already hidden
    if (!this.isVisible(element)) return

    const { dimension, styles, scale } = this.axis(direction)
    // Pin the current natural size so the transition has a starting point.
    this.setSize(element, styles, this.naturalSize(element, dimension) + 'px')
    // Always add transition classes (moving toward a more generalizable collapse method)
    element.classList.add('tw:transition-all', `tw:duration-${duration}`)
    // Add the tailwind class to shrink
    element.classList.add(scale)
    // Force a reflow so the browser commits the natural size before transitioning.
    this.reflow(element)
    // Transition to size 0
    this.setSize(element, styles, '0px')

    // After transition completes, add display: none to remove element from the flow
    element._collapseFinalizer = setTimeout(() => {
      element.classList.add('tw:hidden!')
      element._collapseFinalizer = null
    }, duration)
  }

  static _cancelFinalizer (element) {
    if (element._collapseFinalizer) {
      clearTimeout(element._collapseFinalizer)
      element._collapseFinalizer = null
    }
  }

  /**
   * Checks if an element is visible in the viewport
   * @param {HTMLElement} element - The element to check
   * @return {boolean} - True if element is visible
   */
  static isVisible (element) {
    // check display, visibility and opacity
    if (window.getComputedStyle(element).display === 'none') return false
    if (window.getComputedStyle(element).visibility === 'hidden') return false
    if (window.getComputedStyle(element).opacity === '0') return false

    return true
  }
}

/**
 * Convenient function that delegates to the CollapseUtils class method
 * @param {string} action - 'show', 'hide', or 'toggle'
 * @param {HTMLElement} element - The element to manipulate
 * @param {number} duration - Animation duration in milliseconds
 * @param {string} direction - 'vertical' (height) or 'horizontal' (width)
 */
export function collapse (action, element, duration = 200, direction = 'vertical') {
  return CollapseUtils.collapse(action, element, duration, direction)
}
