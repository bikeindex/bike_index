import { Controller } from '@hotwired/stimulus'

// $mainmenu-transform-speed in primary_header_nav.scss
const TRANSITION_MS = 200

// Connects to data-controller="page-block--navbar"
//
// The site header: the hamburgler menu below the lg breakpoint, and the organization
// and settings dropdowns. The classes it toggles are the ones primary_header_nav.scss
// already styles, so `open` lands on a toggle's parent the way bootstrap's did.
export default class extends Controller {
  static targets = ['menu', 'backdrop', 'hamburgler', 'hamburglerButton', 'dropdownToggle', 'organizationToggle']

  connect () {
    // Set here rather than in the template so it isn't rendered for lynx
    this.hamburglerButtonTarget.innerHTML = '&#9776;'
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
    const wasOpen = toggle.getAttribute('aria-expanded') === 'true'

    this.closeDropdowns()
    if (wasOpen) return

    toggle.setAttribute('aria-expanded', 'true')
    toggle.parentElement.classList.add('open')
  }

  closeDropdowns () {
    this.dropdownToggleTargets.forEach((toggle) => {
      toggle.setAttribute('aria-expanded', 'false')
      toggle.parentElement.classList.remove('open')
    })
  }

  closeDropdownsOutside (event) {
    if (!this.element.contains(event.target)) this.closeDropdowns()
  }

  closeOnEscape () {
    this.closeDropdowns()
    if (!this.menuOpen) return

    this.closeMenu()
    this.hamburglerButtonTarget.focus()
  }

  // Rotating or resizing with the menu open changes how tall the banner is
  reposition () {
    if (this.menuOpen) this.positionMenu()
  }

  get menuOpen () {
    return this.element.classList.contains('menu-in')
  }

  // The menu and its backdrop are fixed to the viewport, but the navbar isn't -
  // the review-app banner pushes it down, further still when the PR title wraps.
  // So sit them below wherever the hamburgler actually ends, rather than assuming
  positionMenu () {
    if (this.hamburglerTarget.offsetParent === null) return

    const top = `${this.hamburglerTarget.getBoundingClientRect().bottom}px`
    this.menuTarget.style.top = top
    this.backdropTarget.style.top = top
  }

  // A wide passive organization name overflows and hides the rest of the small-screen
  // navbar, so cap it at what the logo and the hamburgler leave. There is also a 16px
  // margin and a bunch of padding on either side, so subtract that as well
  truncateOrganizationName () {
    if (window.innerWidth >= 768 || !this.hasOrganizationToggleTarget) return

    const available = this.element.querySelector('.container').clientWidth -
      this.element.querySelector('.primary-logo').offsetWidth -
      this.hamburglerTarget.offsetWidth
    this.organizationToggleTarget.style.maxWidth = `${available - 102}px`
  }
}
