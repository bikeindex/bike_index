import { Controller } from '@hotwired/stimulus'

/* global localStorage */

// Connects to data-controller='org--registration-search-column-toggle'
export default class extends Controller {
  static targets = ['checkboxes']
  static values = { enabledColumns: Array, defaultColumns: Array, assignBikeSticker: Boolean }

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
    this.enabledColumnsValue = [...this.element.querySelectorAll('th.hideableColumn')].map(th =>
      [...th.classList].find(c => c.endsWith('_cell'))
    ).filter(Boolean)

    if (this.assignBikeStickerValue) {
      this.enabledColumnsValue.push('assign_bike_sticker_cell')
    }
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

    if (this.assignBikeStickerValue) {
      checked.push('assign_bike_sticker_cell')
    }

    const firstVisible = this.enabledColumnsValue.find(col => checked.includes(col))
    // When initially rendering, or if none selected, return early
    if (!firstVisible) return
    const lastVisible = [...this.enabledColumnsValue].reverse().find(col => checked.includes(col))

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
