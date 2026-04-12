import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui-table'
// Applies first/last visible column styles (rounding, borders) that CSS
// :first-child can't handle when columns are hidden via display:none.
export default class extends Controller {
  connect () {
    this.applyEdgeStyles()
  }

  applyEdgeStyles () {
    const table = this.element.querySelector('table.ui-table')
    if (!table) return

    const bordered = table.classList.contains('ui-table-bordered')

    // Header row
    const headerRow = table.querySelector('thead tr')
    if (headerRow) {
      const firstTh = this.firstVisible(headerRow, 'th')
      if (firstTh) {
        firstTh.classList.add('tw:rounded-tl-sm')
        if (bordered) firstTh.classList.add('tw:ui-table-bordered-th-first')
      }
    }

    // Body rows - first visible td in last row gets bottom-left rounding
    const bodyRows = table.querySelectorAll('tbody tr')
    if (bodyRows.length > 0) {
      const lastRow = bodyRows[bodyRows.length - 1]
      const firstTd = this.firstVisible(lastRow, 'td')
      if (firstTd) firstTd.classList.add('tw:rounded-bl-sm')
    }

    // Bordered: first visible td in every row
    if (bordered) {
      bodyRows.forEach(row => {
        const firstTd = this.firstVisible(row, 'td')
        if (firstTd) firstTd.classList.add('tw:ui-table-bordered-td-first')
      })
    }
  }

  firstVisible (row, tag) {
    return Array.from(row.querySelectorAll(tag)).find(el =>
      getComputedStyle(el).display !== 'none'
    )
  }
}
