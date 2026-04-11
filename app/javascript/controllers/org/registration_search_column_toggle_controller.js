import { Controller } from '@hotwired/stimulus'

/* global localStorage */

// Connects to data-controller='org--registration-search-column-toggle'
export default class extends Controller {
  static targets = ['checkboxes']
  static values = { enabledColumns: Array, defaultColumns: Array }

  connect () {
    this.refreshEnabledColumns()
    this.selectStoredVisibleColumns()
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.handleFrameRender)
  }

  handleFrameRender = (event) => {
    if (!this.element.contains(event.target)) return
    this.refreshEnabledColumns()
    this.updateVisibleColumns()
  }

  refreshEnabledColumns () {
    const columns = [...this.element.querySelectorAll('th.hideableColumn')].map(th =>
      [...th.classList].find(c => c.endsWith('_cell'))
    ).filter(Boolean)

    const stickerEl = this.element.querySelector('[data-org--assign-bike-sticker-sticker-path-value]')
    if (stickerEl) {
      columns.push('assign_bike_sticker_cell')
    }

    this.enabledColumnsValue = columns
  }

  columnToggled () {
    this.updateVisibleColumns()
  }

  selectStoredVisibleColumns () {
    const stored = localStorage.getItem('orgRegistrationColumns')
    let columns = this.defaultColumnsValue
    if (stored) {
      try { columns = JSON.parse(stored) } catch { localStorage.removeItem('orgRegistrationColumns') }
    }

    this.checkboxesTarget.querySelectorAll('input[type=checkbox]').forEach(cb => {
      cb.checked = columns.includes(cb.name)
    })
    this.updateVisibleColumns()
  }

  updateVisibleColumns () {
    const checked = []
    this.checkboxesTarget.querySelectorAll('input[type=checkbox]').forEach(cb => {
      if (cb.checked) checked.push(cb.name)
    })
    localStorage.setItem('orgRegistrationColumns', JSON.stringify(checked))

    const firstVisible = this.enabledColumnsValue.find(col => checked.includes(col))
    // When initially rendering, or if none selected, return early
    if (!firstVisible) return;
    const lastVisible = [...this.enabledColumnsValue].reverse().find(col => checked.includes(col))
    console.log(firstVisible)

    const borderClasses = {
      th: { first: 'tw:ui-table-bordered-th-first', last: 'tw:ui-table-bordered-th-last' },
      td: { first: 'tw:ui-table-bordered-td-first', last: 'tw:ui-table-bordered-td-last' }
    }

    this.enabledColumnsValue.forEach(col => {
      const isVisible = checked.includes(col)
      this.element.querySelectorAll(`.${col}`).forEach(el => {
        el.classList.toggle('tw:hidden', !isVisible)
        const tag = el.tagName === 'TH' ? 'th' : 'td'
        el.classList.toggle(borderClasses[tag].first, col === firstVisible)
        el.classList.toggle(borderClasses[tag].last, col === lastVisible)
      })
    })
  }
}
