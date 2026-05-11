import { Controller } from '@hotwired/stimulus'

/* global CSS, getComputedStyle, requestAnimationFrame, cancelAnimationFrame */

// Connects to data-controller='ui--table'
// Applies first/last visible column styles (rounding, borders) that CSS
// :first-child/:last-child can't handle when columns are hidden.
export default class extends Controller {
  static values = {
    sticky: { type: Boolean, default: false }
  }

  connect () {
    this.applyEdgeStyles()
    this.boundRefresh = () => this.applyEdgeStyles()
    this.boundResize = () => this.onResize()
    window.addEventListener('ui-table:refresh', this.boundRefresh)
    window.addEventListener('resize', this.boundResize)

    if (this.stickyValue) {
      this.boundScroll = () => this.onScroll()
      this.setupSticky()
    }
  }

  disconnect () {
    if (this.boundRefresh) {
      window.removeEventListener('ui-table:refresh', this.boundRefresh)
    }
    if (this.boundResize) {
      window.removeEventListener('resize', this.boundResize)
    }
    if (this.boundScroll) {
      window.removeEventListener('scroll', this.boundScroll)
    }
    if (this.resizeFrame) cancelAnimationFrame(this.resizeFrame)
  }

  onResize () {
    if (this.resizeFrame) return
    this.resizeFrame = requestAnimationFrame(() => {
      this.resizeFrame = null
      this.applyEdgeStyles()
      if (this.stickyValue) this.setupSticky()
    })
  }

  refresh () {
    this.applyEdgeStyles()
  }

  setupSticky () {
    const wrapper = this.element
    const table = wrapper.querySelector('table.ui-table')
    const headerRow = table?.querySelector('thead tr')
    if (!table || !headerRow) return

    const ths = headerRow.querySelectorAll('th')
    ths.forEach(th => {
      th.style.transform = ''
      th.style.willChange = ''
      th.classList.remove('tw:sticky', 'tw:top-0')
    })

    const needsHorizontalScroll = table.scrollWidth > wrapper.clientWidth

    if (needsHorizontalScroll) {
      wrapper.classList.add('tw:overflow-x-scroll')
      ths.forEach(th => { th.style.willChange = 'transform' })
      this.cacheMeasurements(table, headerRow, ths)
      this.bindScroll()
      this.applyTransformSticky()
    } else {
      wrapper.classList.remove('tw:overflow-x-scroll')
      ths.forEach(th => th.classList.add('tw:sticky', 'tw:top-0'))
      this.unbindScroll()
    }
  }

  cacheMeasurements (table, headerRow, ths) {
    const rect = table.getBoundingClientRect()
    this.tableTop = rect.top + window.scrollY
    this.tableHeight = rect.height
    this.headerHeight = headerRow.offsetHeight
    this.stickyThs = ths
  }

  bindScroll () {
    window.addEventListener('scroll', this.boundScroll, { passive: true })
  }

  unbindScroll () {
    window.removeEventListener('scroll', this.boundScroll)
  }

  onScroll () {
    if (this.rafPending) return
    this.rafPending = true
    requestAnimationFrame(() => {
      this.applyTransformSticky()
      this.rafPending = false
    })
  }

  applyTransformSticky () {
    if (!this.stickyThs) return
    const offset = window.scrollY - this.tableTop
    const maxOffset = this.tableHeight - this.headerHeight
    let applied = 0
    if (offset > 0 && maxOffset > 0) {
      applied = Math.min(offset, maxOffset)
    }
    const translate = applied ? `translateY(${applied}px)` : ''
    this.stickyThs.forEach(th => {
      if (th.style.transform !== translate) th.style.transform = translate
    })
  }

  applyEdgeStyles () {
    const table = this.element.querySelector('table.ui-table')
    if (!table) return

    const bordered = table.classList.contains('ui-table-bordered')
    const thFirst = bordered ? 'tw:ui-table-bordered-th-first' : 'tw:rounded-tl-sm'
    const thLast = bordered ? 'tw:ui-table-bordered-th-last' : 'tw:rounded-tr-sm'
    const tdFirst = bordered ? 'tw:ui-table-bordered-td-first' : 'tw:rounded-bl-sm'
    const tdLast = bordered ? 'tw:ui-table-bordered-td-last' : 'tw:rounded-br-sm'
    const allClasses = [thFirst, thLast, tdFirst, tdLast]

    // Clear previous edge styles
    allClasses.forEach(cls => {
      table.querySelectorAll(`.${CSS.escape(cls)}`).forEach(el => el.classList.remove(cls))
    })

    // Header row
    const headerRow = table.querySelector('thead tr')
    if (headerRow) {
      const ths = this.visibleCells(headerRow, 'th')
      if (ths.length) {
        ths[0].classList.add(thFirst)
        ths[ths.length - 1].classList.add(thLast)
      }
    }

    // Body rows
    const bodyRows = table.querySelectorAll('tbody tr')
    if (bordered) {
      bodyRows.forEach(row => {
        const tds = this.visibleCells(row, 'td')
        if (tds.length) {
          tds[0].classList.add(tdFirst)
          tds[tds.length - 1].classList.add(tdLast)
        }
      })
    } else if (bodyRows.length > 0) {
      const lastRow = bodyRows[bodyRows.length - 1]
      const tds = this.visibleCells(lastRow, 'td')
      if (tds.length) {
        tds[0].classList.add(tdFirst)
        tds[tds.length - 1].classList.add(tdLast)
      }
    }
  }

  visibleCells (row, tag) {
    return Array.from(row.querySelectorAll(tag)).filter(el =>
      getComputedStyle(el).display !== 'none'
    )
  }
}
