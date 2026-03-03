import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global localStorage */

export default class extends Controller {
  static targets = ['settings', 'perPage']
  static values = { defaultColumns: Array }

  connect () {
    this.selectStoredVisibleColumns()
    if (localStorage.getItem('orgBikeSettingsOpen') === 'true') {
      collapse('show', this.settingsTarget, 0)
    }
  }

  toggleSettings () {
    const wasHidden = this.settingsTarget.classList.contains('tw:hidden!') ||
      this.settingsTarget.classList.contains('tw:hidden')
    collapse('toggle', this.settingsTarget)
    localStorage.setItem('orgBikeSettingsOpen', wasHidden ? 'true' : 'false')
  }

  columnToggled () {
    this.updateVisibleColumns()
  }

  averyToggled (event) {
    const url = new URL(window.location)
    if (event.target.checked) {
      url.searchParams.set('search_avery_export', 'true')
    } else {
      url.searchParams.delete('search_avery_export')
    }
    window.location = url.toString()
  }

  perPageChanged () {
    const url = new URL(window.location)
    url.searchParams.set('per_page', this.perPageTarget.value)
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
    this.settingsTarget.querySelectorAll('input[type=checkbox]').forEach(cb => {
      if (cb.dataset.action && cb.dataset.action.includes('averyToggled')) return
      if (cb.checked) checked.push(cb.name)
    })
    localStorage.setItem('orgBikeColumns', JSON.stringify(checked))

    this.element.querySelectorAll('.hiddenColumn').forEach(el => {
      const isVisible = checked.some(col => el.classList.contains(col))
      el.style.display = isVisible ? '' : 'none'
    })
  }
}
