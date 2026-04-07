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

  handleFrameRender = () => {
    this.refreshEnabledColumns()
    this.updateVisibleColumns()
  }

  refreshEnabledColumns () {
    this.enabledColumnsValue = [...this.element.querySelectorAll('th.hideableColumn')].map(th =>
      [...th.classList].find(c => c.endsWith('_cell'))
    ).filter(Boolean)
  }

  columnToggled () {
    this.updateVisibleColumns()
  }

  // Avery export requires a page reload because the server conditionally
  // renders avery column cells based on the search_avery_export param
  averyToggled (event) {
    const url = new URL(window.location)
    if (event.target.checked) {
      url.searchParams.set('search_avery_export', 'true')
    } else {
      url.searchParams.delete('search_avery_export')
    }
    url.searchParams.set('search_no_js', 'true')
    window.location = url.toString()
  }

  selectStoredVisibleColumns () {
    const stored = localStorage.getItem('orgRegistrationColumns')
    let columns = this.defaultColumnsValue
    if (stored) {
      try { columns = JSON.parse(stored) } catch { localStorage.removeItem('orgRegistrationColumns') }
    }

    this.checkboxesTarget.querySelectorAll('input[type=checkbox]').forEach(cb => {
      if (cb.dataset.action && cb.dataset.action.includes('averyToggled')) return
      cb.checked = columns.includes(cb.name)
    })
    this.updateVisibleColumns()
  }

  updateVisibleColumns () {
    const checked = []
    const visible = []
    this.checkboxesTarget.querySelectorAll('input[type=checkbox]').forEach(cb => {
      if (cb.dataset.action && cb.dataset.action.includes('averyToggled')) {
        // Avery state is URL-driven, not stored in localStorage, but still
        // needs to be in the visible list so the column cells are shown
        if (cb.checked) visible.push(cb.name)
        return
      }
      if (cb.checked) {
        checked.push(cb.name)
        visible.push(cb.name)
      }
    })
    // Store enabled columns so they persist across page loads
    localStorage.setItem('orgRegistrationColumns', JSON.stringify(checked))

    this.enabledColumnsValue.forEach(col => {
      const isVisible = visible.includes(col)
      this.element.querySelectorAll(`.${col}`).forEach(el => {
        el.classList.toggle('tw:hidden', !isVisible)
      })
    })
  }
}
