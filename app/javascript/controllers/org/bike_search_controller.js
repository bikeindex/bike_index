import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global localStorage */

// Connects to data-controller='org--bike-search'
export default class extends Controller {
  static targets = ['settings', 'settingsButton', 'perPage']
  static values = { defaultColumns: Array }

  connect () {
    this.selectStoredVisibleColumns()
    if (localStorage.getItem('orgBikeSettingsOpen') === 'true') {
      collapse('show', this.settingsTarget, 0)
      if (this.hasSettingsButtonTarget) this.settingsButtonTarget.classList.add('active')
    }
  }

  toggleSettings () {
    const wasHidden = this.settingsTarget.classList.contains('tw:hidden!') ||
      this.settingsTarget.classList.contains('tw:hidden')
    collapse('toggle', this.settingsTarget)
    localStorage.setItem('orgBikeSettingsOpen', wasHidden ? 'true' : 'false')
    if (this.hasSettingsButtonTarget) this.settingsButtonTarget.classList.toggle('active', wasHidden)
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

  perPageChanged () {
    const url = new URL(window.location)
    url.searchParams.set('per_page', this.perPageTarget.value)
    url.searchParams.set('search_no_js', 'true')
    window.location = url.toString()
  }

  selectStoredVisibleColumns () {
    const stored = localStorage.getItem('orgBikeColumns')
    let columns = this.defaultColumnsValue
    if (stored) {
      try { columns = JSON.parse(stored) } catch { localStorage.removeItem('orgBikeColumns') }
    }

    this.settingsTarget.querySelectorAll('input[type=checkbox]').forEach(cb => {
      if (cb.dataset.action && cb.dataset.action.includes('averyToggled')) return
      cb.checked = columns.includes(cb.name)
    })
    this.updateVisibleColumns()
  }

  updateVisibleColumns () {
    const checked = []
    const visible = []
    this.settingsTarget.querySelectorAll('input[type=checkbox]').forEach(cb => {
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
    localStorage.setItem('orgBikeColumns', JSON.stringify(checked))

    this.element.querySelectorAll('.hiddenColumn').forEach(el => {
      const isVisible = visible.some(col => el.classList.contains(col))
      el.style.display = isVisible ? '' : 'none'
    })
  }
}
