import { Controller } from '@hotwired/stimulus'

const EXPANDED_WIDTH = '266px'
const COLLAPSED_WIDTH = '68px'

// Connects to data-controller="page-block--org-sidebar"
//
// Below mobileBreakpoint the sidebar is a top bar in the flow whose menu the hamburgler
// opens; above it, a column that collapses to an icon rail under collapseBreakpoint.
// Every width and visibility rule is a tailwind variant on data-collapsed /
// data-mobile-open, so this only sets those two — and the custom property the content
// column reads. The account menu is a UI::Dropdown and looks after itself.
export default class extends Controller {
  static targets = ['mobileToggle', 'collapseToggle']
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
    this.render()
  }

  toggleMobile () {
    this.setMobileOpen(!this.mobileOpen)
  }

  // Collapsed there's nowhere to put a group's children -- ui--collapse animates them
  // open right after this, so the rail has to be expanded by then
  expandForGroup () {
    if (!this.collapsed) return

    this.override = false
    this.render()
  }

  closeOnEscape () {
    if (!this.mobileOpen) return

    this.setMobileOpen(false)
    this.mobileToggleTarget.focus()
  }

  setMobileOpen (open) {
    this.element.dataset.mobileOpen = open
    this.mobileToggleTarget.setAttribute('aria-expanded', open)
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
}
