import { Controller } from '@hotwired/stimulus'

const EXPANDED_WIDTH = '266px'
const COLLAPSED_WIDTH = '68px'
// ui--collapse's default, so a group's rows are in place before they're measured
const TRANSITION_MS = 200

// Connects to data-controller="page-block--org-sidebar"
//
// Below mobileBreakpoint the sidebar is a top bar in the flow whose menu the hamburgler
// opens; above it, a column that collapses to an icon rail under collapseBreakpoint.
// Every width and visibility rule is a tailwind variant on data-collapsed /
// data-mobile-open, so this only sets those two — and the custom property the content
// column reads. The account menu is a UI::Dropdown and looks after itself.
export default class extends Controller {
  static targets = ['mobileToggle', 'collapseToggle', 'scroller']
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

  // Collapsed, the rail hides a group's children with a css variant rather than the
  // class ui--collapse reads, so a group left open before the rail collapsed would
  // toggle *shut* on the way back out. Opening explicitly is what the reader asked for
  // by clicking it, so this owns the decision rather than letting a second action race it
  toggleGroup (event) {
    const trigger = event.currentTarget
    const group = this.groupFor(trigger)

    if (!this.collapsed) {
      group.toggle()
    } else {
      this.override = false
      this.render()
      group.show()
    }

    this.revealGroup(trigger)
  }

  groupFor (trigger) {
    return this.application.getControllerForElementAndIdentifier(
      trigger.closest('[data-controller~="ui--collapse"]'), 'ui--collapse')
  }

  // A group near the bottom unrolls past the fold, which is no use to whoever opened it.
  // Measured after ui--collapse animates the rows in, rather than against a panel that
  // is still zero-height. Scrolls by exactly what overflows, so the row clicked stays put
  // where the whole group can fit; only a group taller than the view gives that up to
  // show its start. The sidebar scrolls as a column and the page does once it's in the flow
  revealGroup (trigger) {
    setTimeout(() => {
      const panel = document.getElementById(trigger.getAttribute('aria-controls'))
      const scroller = this.scrollerTarget
      const scrolls = scroller.scrollHeight > scroller.clientHeight
      const view = scroller.getBoundingClientRect()
      const viewTop = scrolls ? view.top : 0
      const viewBottom = scrolls ? view.bottom : window.innerHeight
      const groupTop = trigger.getBoundingClientRect().top
      const groupBottom = panel.getBoundingClientRect().bottom

      if (groupTop >= viewTop && groupBottom <= viewBottom) return

      const delta = (groupBottom - groupTop > viewBottom - viewTop)
        ? groupTop - viewTop
        : groupBottom - viewBottom

      const target = scrolls ? scroller : window
      target.scrollBy({ top: delta, behavior: 'smooth' })
    }, TRANSITION_MS)
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

  // resize fires continuously through a drag, where collapsed crosses a breakpoint at
  // most twice -- and every write here invalidates style for the whole document
  render () {
    const { collapsed } = this
    if (collapsed === this.rendered) return

    this.rendered = collapsed
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
