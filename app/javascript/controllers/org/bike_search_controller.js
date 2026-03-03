import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global localStorage */

export default class extends Controller {
  static targets = ['settings', 'perPage']
  static values = { defaultColumns: Array }

  connect () {
    this.selectStoredVisibleColumns()
  }

  toggleSettings () {
    collapse('toggle', this.settingsTarget)
  }

  columnToggled () {
    this.updateVisibleColumns()
  }

  averyToggled (event) {
    const checked = event.target.checked
    const url = new URL(window.location)
    url.searchParams.set('search_avery_export', checked)
    window.location = url.toString()
  }

  perPageChanged () {
    const url = new URL(window.location)
    url.searchParams.set('per_page', this.perPageTarget.value)
    window.location = url.toString()
  }

  selectStoredVisibleColumns () {
    const stored = localStorage.getItem('orgBikeColumns')
    const columns = stored ? JSON.parse(stored) : this.defaultColumnsValue

    this.settingsTarget.querySelectorAll('input[type=checkbox]').forEach(cb => {
      cb.checked = columns.includes(cb.name)
    })
    this.updateVisibleColumns()
  }

  updateVisibleColumns () {
    const checked = []
    this.settingsTarget.querySelectorAll('input[type=checkbox]').forEach(cb => {
      if (cb.checked) checked.push(cb.name)
    })
    localStorage.setItem('orgBikeColumns', JSON.stringify(checked))

    this.element.querySelectorAll('.hiddenColumn').forEach(el => {
      const isVisible = checked.some(col => el.classList.contains(col))
      el.style.display = isVisible ? '' : 'none'
    })
  }
}
