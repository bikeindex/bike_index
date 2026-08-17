import { Controller } from '@hotwired/stimulus'

const EXPANDED_WIDTH = '266px'
const COLLAPSED_WIDTH = '68px'

// Connects to data-controller="page-block--org-sidebar"
//
// Below mobileBreakpoint the sidebar is an overlay behind the top bar's hamburgler;
// above it, a column that collapses to an icon rail under collapseBreakpoint. Every
// width and visibility rule is a tailwind variant on data-collapsed / data-mobile-open,
// so this only sets those two — and the custom property the content column reads.
export default class extends Controller {
  static targets = ['mobileToggle', 'collapseToggle', 'accountMenu', 'accountToggle']
  static values = { collapseBreakpoint: Number, mobileBreakpoint: Number }

  connect () {
    // Null until the reader collapses or expands it themselves, after which their
    // choice outranks the breakpoint for the rest of the page
    this.override = null
    this.render()
  }

  disconnect () {
    document.documentElement.style.removeProperty('--org-sidebar-width')
  }

  resize () {
    this.render()
  }

  toggleCollapse () {
    this.override = !this.collapsed
    this.closeAccount()
    this.render()
  }

  toggleMobile () {
    this.setMobileOpen(!this.mobileOpen)
  }

  // Collapsed there's nowhere to put a group's children -- ui--collapse animates them
  // open right after this, so the rail has to be expanded by then
  expandForGroup () {
    if (this.collapsed) {
      this.override = false
      this.render()
    }
    this.closeAccount()
  }

  toggleAccount (event) {
    event.stopPropagation()

    if (this.collapsed) {
      this.override = false
      this.render()
      this.setAccountOpen(true)
      return
    }

    this.setAccountOpen(!this.accountOpen)
  }

  closeAccountOutside (event) {
    if (this.accountOpen && !this.element.contains(event.target)) this.closeAccount()
  }

  closeOnEscape () {
    this.closeAccount()
    if (!this.mobileOpen) return

    this.setMobileOpen(false)
    this.mobileToggleTarget.focus()
  }

  setAccountOpen (open) {
    this.accountToggleTarget.setAttribute('aria-expanded', open)
    this.accountMenuTarget.classList.toggle('tw:hidden', !open)
    this.accountMenuTarget.classList.toggle('tw:flex', open)
  }

  closeAccount () {
    this.setAccountOpen(false)
  }

  setMobileOpen (open) {
    this.element.dataset.mobileOpen = open
    this.mobileToggleTarget.setAttribute('aria-expanded', open)
    if (!open) this.closeAccount()
  }

  render () {
    const { collapsed } = this
    this.element.dataset.collapsed = collapsed

    const { collapseLabel, expandLabel } = this.collapseToggleTarget.dataset
    const label = collapsed ? expandLabel : collapseLabel
    this.collapseToggleTarget.setAttribute('aria-label', label)
    this.collapseToggleTarget.setAttribute('title', label)

    // Only ever expanded-or-collapsed: the mobile case is the stylesheet's, which
    // zeroes the margin below the breakpoint. Reporting 0px here instead would put
    // the content under the sidebar for as long as this and the media query disagree
    document.documentElement.style.setProperty('--org-sidebar-width',
      collapsed ? COLLAPSED_WIDTH : EXPANDED_WIDTH)
  }

  get mobile () {
    return window.innerWidth < this.mobileBreakpointValue
  }

  get collapsed () {
    if (this.mobile) return false
    if (this.override !== null) return this.override

    return window.innerWidth < this.collapseBreakpointValue
  }

  get mobileOpen () {
    return this.element.dataset.mobileOpen === 'true'
  }

  get accountOpen () {
    return this.accountToggleTarget.getAttribute('aria-expanded') === 'true'
  }
}
