// collapse-utils.js
// Utility class for handling element collapse animations

// The only place this was used was removed in #2773
// check that PR to see how to use it

/**
 * CollapseUtils class providing element collapse/expand functionality
 */
export class CollapseUtils {
  /**
   * Handle collapsing or showing elements with animation
   * @param {string} action - 'show' or 'hide'
   * @param {HTMLElement} element - The element to manipulate
   * @param {number} duration - Animation duration in milliseconds
   */
  static collapse (action, element, duration) {
    if (!element) {
      console.warn('Cannot collapse undefined or null element')
      return
    }

    if (action === 'show') {
      this.show(element, duration)
    } else if (action === 'hide') {
      this.hide(element, duration)
    } else if (action === 'toggle') {
      this.toggle(element, duration)
    } else {
      console.warn(`Invalid CollapseUtils action: ${action}. must be one of: 'show', 'hide', 'toggle'`)
    }
  }

  /**
   * Toggle element visibility
   * @param {HTMLElement} element - The element to toggle
   * @param {number} duration - Animation duration in milliseconds
   */
  static toggle (element, duration) {
    if (!element) return

    const isHidden = element.classList.contains('tw:hidden!')
    this.collapse(isHidden ? 'show' : 'hide', element, duration)
  }

  /**
   * Show/uncollapse an element with animation
   * @param {HTMLElement} element - The element to uncollapse
   * @param {number} duration - Animation duration in milliseconds
   */
  static show (element, duration) {
    // Return early if already visible
    if (this.isVisible(element)) return;
    // Remove the hidden
    element.classList.remove('tw:hidden!')
    // First, ensure the hidden attributes are set
    element.classList.add('tw:scale-y-0')
    element.style.height = 0
    // Always add transition classes (moving toward a more generalizable collapse method)
    element.classList.add('tw:transition-all', `tw:duration-${duration}`)
    // Remove things that transition to hide the element
    element.classList.remove('tw:scale-y-0')
    // Set the element's height to its natural height to expand it
    element.style.height = `${element.scrollHeight}px`

    // After transition is complete, remove explicit height (clean up afterward)
    setTimeout(() => {
      element.style.height = ''
    }, duration)
  }

  /**
   * Hide/collapse an element with animation
   * @param {HTMLElement} element - The element to collapse
   * @param {number} duration - Animation duration in milliseconds
   */
  static hide (element, duration) {
    // Return early if already hidden
    if (!this.isVisible(element)) return;

    // Always add transition classes (moving toward a more generalizable collapse method)
    element.classList.add('tw:transition-all', `tw:duration-${duration}`)
    // Add the tailwind class to shrink
    element.classList.add('tw:scale-y-0')
    // Set an explicit height to enable the transition
    element.style.height = element.scrollHeight + 'px'
    // Transition to height 0
    element.style.height = '0px'

    // After transition completes, add display: none to remove element from the flow
    setTimeout(() => {
      element.classList.add('tw:hidden!')
    }, duration)
  }

  /**
   * Checks if an element is visible in the viewport
   * @param {HTMLElement} element - The element to check
   * @return {boolean} - True if element is visible
   */
  static isVisible (element) {
    // check display, visibility and opacity
    if (window.getComputedStyle(element).display === 'none') return false;
    if (window.getComputedStyle(element).visibility === 'hidden') return false;
    if (window.getComputedStyle(element).opacity === '0') return false;

    return true
  }
}

/**
 * Convenient function that delegates to the CollapseUtils class method
 * @param {string} action - 'show', 'hide', or 'toggle'
 * @param {HTMLElement} element - The element to manipulate
 * @param {number} duration - Animation duration in milliseconds
 */
export function collapse (action, element, duration = 200) {
  return CollapseUtils.collapse(action, element, duration)
}
