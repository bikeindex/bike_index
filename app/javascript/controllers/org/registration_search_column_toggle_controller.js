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
    // Stimulus Array values return a fresh copy on each read, so mutating
    // via push won't persist (and assign_bike_sticker_cell is ignored)
    // build the full array, then assign it once.
    const columns = [...this.element.querySelectorAll('th.hideableColumn')].map(th =>
      [...th.classList].find(c => c.endsWith('_cell'))
    ).filter(Boolean)

    if (this.assignBikeStickerValue) {
      columns.push('assign_bike_sticker_cell')
    }

    this.enabledColumnsValue = columns
  }

  columnToggled () {
    this.updateVisibleColumns()
  }

  selectAll () {
    this.setAllCheckboxes(true)
  }

  selectNone () {
    this.setAllCheckboxes(false)
  }

  selectDefault () {
    const defaults = this.defaultColumnsValue
    this.checkboxesTarget.querySelectorAll('input[type=checkbox]').forEach(cb => {
      cb.checked = defaults.includes(cb.name)
    })
    this.updateVisibleColumns()
  }

  setAllCheckboxes (checked) {
    this.checkboxesTarget.querySelectorAll('input[type=checkbox]').forEach(cb => {
      cb.checked = checked
    })
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

    this.enabledColumnsValue.forEach(col => {
      const isVisible = checked.includes(col)
      this.element.querySelectorAll(`.${col}`).forEach(el => {
        el.classList.toggle('tw:hidden', !isVisible)
      })
    })

    // Re-apply first/last visible column border styles via ui-table controller
    window.dispatchEvent(new Event('ui-table:refresh'))
  }
}
