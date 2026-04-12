import { Controller } from '@hotwired/stimulus'

/* global CSS, getComputedStyle */

// Connects to data-controller='ui-table'
// Applies first/last visible column styles (rounding, borders) that CSS
// :first-child/:last-child can't handle when columns are hidden.
export default class extends Controller {
  connect () {
    this.applyEdgeStyles()
    this.boundRefresh = () => this.applyEdgeStyles()
    window.addEventListener('ui-table:refresh', this.boundRefresh)
  }

  disconnect () {
    window.removeEventListener('ui-table:refresh', this.boundRefresh)
  }

  refresh () {
    this.applyEdgeStyles()
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
