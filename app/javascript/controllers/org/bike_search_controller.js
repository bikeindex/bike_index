import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global localStorage */

// Connects to data-controller='org--bike-search'
export default class extends Controller {
  static targets = ['settings', 'settingsButton', 'perPage', 'exportLink', 'notesField', 'notesButton']
  static values = { defaultColumns: Array }

  connect () {
    this.selectStoredVisibleColumns()
    if (localStorage.getItem('orgBikeSettingsOpen') === 'true') {
      collapse('show', this.settingsTarget, 0)
      if (this.hasSettingsButtonTarget) this.settingsButtonTarget.classList.add('active')
    }
    this.initNotesSearch()
    // Re-apply column visibility when turbo frame updates with new table content
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.handleFrameRender)
  }

  handleFrameRender = () => {
    this.updateVisibleColumns()
    this.updateExportLink()
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

  initNotesSearch () {
    if (!this.hasNotesFieldTarget) return
    const input = this.notesFieldTarget.querySelector('input')
    const hasValue = input && input.value.length > 0
    if (hasValue || localStorage.getItem('orgBikeNotesSearchOpen') === 'true') {
      this.showNotesSearch()
    }
  }

  toggleNotesSearch () {
    if (!this.hasNotesFieldTarget) return
    const isHidden = this.notesFieldTarget.classList.contains('tw:hidden')
    if (isHidden) {
      this.showNotesSearch()
    } else {
      this.hideNotesSearch()
    }
  }

  showNotesSearch () {
    this.notesFieldTarget.classList.remove('tw:hidden')
    localStorage.setItem('orgBikeNotesSearchOpen', 'true')
    if (this.hasNotesButtonTarget) this.notesButtonTarget.classList.add('active')
  }

  hideNotesSearch () {
    this.notesFieldTarget.classList.add('tw:hidden')
    localStorage.setItem('orgBikeNotesSearchOpen', 'false')
    if (this.hasNotesButtonTarget) this.notesButtonTarget.classList.remove('active')
  }

  filterChanged () {
    const form = document.getElementById('Search_Form')
    if (form) {
      form.requestSubmit()
    }
  }

  perPageChanged () {
    const url = new URL(window.location)
    url.searchParams.set('per_page', this.perPageTarget.value)
    url.searchParams.set('search_no_js', 'true')
    window.location = url.toString()
  }

  updateExportLink () {
    if (!this.hasExportLinkTarget) return
    const url = new URL(window.location)
    url.searchParams.set('create_export', 'true')
    this.exportLinkTarget.href = url.toString()
  }

  selectStoredVisibleColumns () {
    const stored = localStorage.getItem('orgRegistrationColumns')
    let columns = this.defaultColumnsValue
    if (stored) {
      try { columns = JSON.parse(stored) } catch { localStorage.removeItem('orgRegistrationColumns') }
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
    localStorage.setItem('orgRegistrationColumns', JSON.stringify(checked))

    this.element.querySelectorAll('.hiddenColumn').forEach(el => {
      const isVisible = visible.some(col => el.classList.contains(col))
      el.classList.toggle('tw:hidden', !isVisible)
    })
  }
}
