import { Controller } from '@hotwired/stimulus'
import { COLLAPSE_DURATION_MS } from 'utils/collapse_utils'

/* global requestAnimationFrame */

const EXPANDED_WIDTH = '266px'
const COLLAPSED_WIDTH = '68px'
// What a reader moving the page themselves looks like -- a plain scroll event won't do,
// since revealCurrentRow's own scrolling raises one
const READER_SCROLL_EVENTS = ['wheel', 'touchmove', 'keydown']
// Gap below whatever is revealed, so a fractional row height can't leave it a subpixel
// short of the fold
const REVEAL_MARGIN = 8
// Matched by the panel it opens rather than by ui--collapse's target, so a collapse
// nested in the sidebar keeps the data-active that controller gives it
const GROUP_TRIGGER = '[aria-controls^="org_sidebar_group_"]'

// Connects to data-controller="shared-blocks--org-sidebar"
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
    this.watchForReaderScroll()
    // ui--active-link may have marked the current row before this controller existed to
    // hear it say so
    const current = this.element.querySelector('[aria-current]')
    if (current) this.openGroupFor(current)
  }

  disconnect () {
    document.documentElement.style.removeProperty('--org-sidebar-width')
    READER_SCROLL_EVENTS.forEach((name) => window.removeEventListener(name, this.noteReaderScroll))
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

    this.flagCurrentGroup()
    this.revealGroup(trigger)
  }

  // ui--collapse flags its trigger data-active while the group is open, which is the
  // is-active variant the current row is styled with -- so restated after each toggle as
  // what that styling means on a group: it holds the current row, open or not
  flagCurrentGroup () {
    this.element.querySelectorAll(GROUP_TRIGGER).forEach((trigger) => {
      const group = trigger.closest('[data-controller~="ui--collapse"]')
      trigger.dataset.active = String(group?.querySelector('[aria-current]') != null)
    })
  }

  groupFor (trigger) {
    return this.application.getControllerForElementAndIdentifier(
      trigger.closest('[data-controller~="ui--collapse"]'), 'ui--collapse')
  }

  // ui--active-link announces the current row as it marks it
  openCurrentGroup (event) {
    this.openGroupFor(event.target)
  }

  // The template opens the first group, the way the design shows a page no row matches,
  // so this only moves that open state when the current row is in another one. Without
  // animating: it's the state the page loads in rather than something the reader asked for.
  //
  // ui--collapse owns the opening and registers whenever its module resolves, which is not
  // ordered against this one -- so a group that isn't connected yet is waited for rather
  // than skipped, and the row is read from the DOM in case its event fired first
  openGroupFor (link, attempt = 0) {
    const group = link.closest('[data-controller~="ui--collapse"]')
    // A top-level row has no group to open, but is still a row to settle around
    if (!group) return this.settleCurrentRow()

    const collapse = this.collapseFor(group)
    if (!collapse) {
      if (attempt < 30) requestAnimationFrame(() => this.openGroupFor(link, attempt + 1))
      return
    }

    const open = [...this.element.querySelectorAll('[data-ui--collapse-target="trigger"]')]
      .find((trigger) => trigger.getAttribute('aria-expanded') === 'true')

    if (!open || !group.contains(open)) {
      collapse.setExpanded(true, 0)
      if (open) this.groupFor(open)?.setExpanded(false, 0)
    }

    this.settleCurrentRow()
  }

  settleCurrentRow () {
    this.flagCurrentGroup()
    this.revealCurrentRow()
  }

  collapseFor (element) {
    return this.application.getControllerForElementAndIdentifier(element, 'ui--collapse')
  }

  watchForReaderScroll () {
    this.noteReaderScroll = () => { this.readerScrolled = true }
    READER_SCROLL_EVENTS.forEach((name) =>
      window.addEventListener(name, this.noteReaderScroll, { passive: true, once: true }))
  }

  // Only from rest, and once: a reader who has already moved the column is looking at
  // what they chose, and pulling them off it is worse than the row sitting out of sight.
  // On mobile the menu is closed behind the hamburgler, so there's nothing to reveal
  revealCurrentRow () {
    if (this.revealed || this.readerScrolled || this.mobile) return

    const scroller = this.scrollerTarget
    if (scroller.scrollTop !== 0) return

    const row = this.element.querySelector('[aria-current]')?.getBoundingClientRect()
    // A row whose group is still closed has no box to measure -- wait for the group
    if (!row?.height) return

    this.revealed = true
    const view = scroller.getBoundingClientRect()
    if (row.top >= view.top && row.bottom <= view.bottom) return

    scroller.scrollBy({ top: row.bottom - view.bottom + REVEAL_MARGIN, behavior: 'smooth' })
  }

  // A group near the bottom unrolls past the fold, which is no use to whoever opened it.
  // Measured after ui--collapse animates the rows in, rather than against a panel that
  // is still zero-height. Scrolls by what overflows, so the row clicked stays put
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
        : groupBottom - viewBottom + REVEAL_MARGIN

      const target = scrolls ? scroller : window
      target.scrollBy({ top: delta, behavior: 'smooth' })
    }, COLLAPSE_DURATION_MS)
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
