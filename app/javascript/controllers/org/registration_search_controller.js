import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global localStorage */

// Connects to data-controller='org--registration-search'
export default class extends Controller {
  static targets = ['settings', 'settingsButton', 'perPage', 'exportLink', 'notesField', 'notesButton']

  connect () {
    if (localStorage.getItem('orgRegistrationSettingsOpen') === 'true') {
      collapse('show', this.settingsTarget, 0)
      if (this.hasSettingsButtonTarget) this.settingsButtonTarget.classList.add('active')
    }
    this.initNotesSearch()
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.handleFrameRender)
  }

  handleFrameRender = () => {
    this.updateExportLink()
  }

  toggleSettings () {
    const wasHidden = this.settingsTarget.classList.contains('tw:hidden!') ||
      this.settingsTarget.classList.contains('tw:hidden')
    collapse('toggle', this.settingsTarget)
    localStorage.setItem('orgRegistrationSettingsOpen', wasHidden ? 'true' : 'false')
    if (this.hasSettingsButtonTarget) this.settingsButtonTarget.classList.toggle('active', wasHidden)
  }

  initNotesSearch () {
    if (!this.hasNotesFieldTarget) return
    const input = this.notesFieldTarget.querySelector('input')
    const hasValue = input && input.value.length > 0
    if (hasValue || localStorage.getItem('orgRegistrationNotesSearchOpen') === 'true') {
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
    localStorage.setItem('orgRegistrationNotesSearchOpen', 'true')
    if (this.hasNotesButtonTarget) this.notesButtonTarget.classList.add('active')
  }

  hideNotesSearch () {
    this.notesFieldTarget.classList.add('tw:hidden')
    localStorage.setItem('orgRegistrationNotesSearchOpen', 'false')
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
}
