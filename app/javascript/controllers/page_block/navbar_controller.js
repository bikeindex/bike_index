import { Controller } from '@hotwired/stimulus'

// $mainmenu-transform-speed in primary_header_nav.scss
const TRANSITION_MS = 200

// Connects to data-controller="page-block--navbar"
//
// The hamburgler menu and the two dropdowns. It toggles the classes
// primary_header_nav.scss already styles, so `open` lands on a toggle's parent
// the way bootstrap's did.
export default class extends Controller {
  static targets = ['hamburgler', 'hamburglerButton', 'organizationToggle']

  connect () {
    this.truncateOrganizationName()
  }

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
    this.hamburglerButtonTarget.classList.add('active')
    this.hamburglerButtonTarget.setAttribute('aria-expanded', 'true')
    // So that it animates in, rather than appearing
    setTimeout(() => {
      this.element.classList.add('menu-in')
      document.body.classList.add('menu-in')
    }, 50)
  }

  closeMenu () {
    this.hamburglerButtonTarget.classList.remove('active')
    this.hamburglerButtonTarget.setAttribute('aria-expanded', 'false')
    this.element.classList.remove('menu-in')
    document.body.classList.remove('menu-in')
    // Hide it once it has animated out, so it stays hidden even on opera mini
    setTimeout(() => this.element.classList.remove('enabled'), TRANSITION_MS)
  }

  toggleDropdown (event) {
    const toggle = event.currentTarget
    const wasOpen = toggle === this.openDropdown

    this.closeDropdowns()
    if (wasOpen) return

    toggle.setAttribute('aria-expanded', 'true')
    toggle.parentElement.classList.add('open')
    this.openDropdown = toggle
  }

  closeDropdowns () {
    if (!this.openDropdown) return

    this.openDropdown.setAttribute('aria-expanded', 'false')
    this.openDropdown.parentElement.classList.remove('open')
    this.openDropdown = null
  }

  closeDropdownsOutside (event) {
    if (this.openDropdown && !this.openDropdown.parentElement.contains(event.target)) this.closeDropdowns()
  }

  // Escape returns focus to whatever it closed, the way ui--dropdown does -- otherwise
  // it lands on a display:none element and the browser drops it to the body
  closeOnEscape () {
    const openToggle = this.openDropdown

    this.closeDropdowns()
    if (openToggle) {
      openToggle.focus()
    } else if (this.menuOpen) {
      this.closeMenu()
      this.hamburglerButtonTarget.focus()
    }
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

  // A wide passive organization name overflows and hides the rest of the small-screen
  // navbar, so cap it at what the logo and hamburgler leave, less its margin and padding
  truncateOrganizationName () {
    if (!this.hasOrganizationToggleTarget || window.innerWidth >= 768) return

    const available = this.element.querySelector('.container').clientWidth -
      this.element.querySelector('.primary-logo').offsetWidth -
      this.hamburglerTarget.offsetWidth
    this.organizationToggleTarget.style.maxWidth = `${available - 102}px`
  }
}
