import { Controller } from '@hotwired/stimulus'

// $mainmenu-transform-speed in primary_header_nav.scss
const TRANSITION_MS = 200

// Connects to data-controller="page-block--navbar"
//
// The hamburgler menu. The settings dropdown it used to open too is UI::Dropdown's now.
export default class extends Controller {
  static targets = ['hamburgler', 'hamburglerButton']

  toggleMenu () {
    if (this.menuOpen) {
      this.closeMenu()
    } else {
      this.openMenu()
    }
  }

  openMenu () {
    this.positionMenu()
    this.element.classList.add('enabled')
    this.hamburglerButtonTarget.dataset.active = 'true'
    this.hamburglerButtonTarget.setAttribute('aria-expanded', 'true')
    // So that it animates in, rather than appearing
    setTimeout(() => {
      this.element.classList.add('menu-in')
      document.body.classList.add('menu-in')
    }, 50)
  }

  closeMenu () {
    this.hamburglerButtonTarget.dataset.active = 'false'
    this.hamburglerButtonTarget.setAttribute('aria-expanded', 'false')
    this.element.classList.remove('menu-in')
    document.body.classList.remove('menu-in')
    // Hide it once it has animated out, so it stays hidden even on opera mini
    setTimeout(() => this.element.classList.remove('enabled'), TRANSITION_MS)
  }

  // Escape returns focus to what it closed -- otherwise it lands on a display:none
  // element and the browser drops it to the body
  closeOnEscape () {
    if (!this.menuOpen) return

    this.closeMenu()
    this.hamburglerButtonTarget.focus()
  }

  // Rotating or resizing with the menu open changes how tall the banner is
  reposition () {
    if (this.menuOpen) this.positionMenu()
  }

  // menu-in lands a frame later than the button's state, so read the button
  get menuOpen () {
    return this.hamburglerButtonTarget.getAttribute('aria-expanded') === 'true'
  }

  // The menu and its backdrop are fixed to the viewport, but the navbar isn't -
  // the review-app banner pushes it down, further still when the PR title wraps.
  // So sit them below wherever the hamburgler actually ends, rather than assuming
  positionMenu () {
    // A hamburgler hidden above the breakpoint measures all-zero
    const { bottom, height } = this.hamburglerTarget.getBoundingClientRect()
    if (!height) return

    this.element.style.setProperty('--navbar-bottom', `${bottom}px`)
  }
}
