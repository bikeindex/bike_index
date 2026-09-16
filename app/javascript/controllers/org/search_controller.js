import { Controller } from '@hotwired/stimulus'

/* global localStorage */

// Connects to data-controller='org--search'
export default class extends Controller {
  static targets = ['perPage', 'exportLink', 'notesField', 'notesCheckbox', 'chartFrame']

  connect () {
    this.chartSearch = window.location.search
    this.initNotesSearch()
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.handleFrameRender)
  }

  // The column panel and the chart render inside frames the search replaces. The panel
  // looks after itself - ui--collapse reconnects with it - but the chart is outside them.
  handleFrameRender = (event) => {
    if (this.hasChartFrameTarget && event.target === this.chartFrameTarget) return
    this.updateExportLink()
    this.reloadChart()
  }

  initNotesSearch () {
    if (!this.hasNotesFieldTarget) return
    const input = this.notesFieldTarget.querySelector('input')
    const hasValue = input && input.value.length > 0
    if (hasValue || localStorage.getItem('orgRegistrationNotesSearchOpen') === 'true') {
      this.setNotesSearch(true)
    }
  }

  toggleNotesSearch () {
    if (!this.hasNotesFieldTarget) return
    this.setNotesSearch(this.notesFieldTarget.classList.contains('tw:hidden'))
  }

  setNotesSearch (open) {
    this.notesFieldTarget.classList.toggle('tw:hidden', !open)
    localStorage.setItem('orgRegistrationNotesSearchOpen', String(open))
    if (this.hasNotesCheckboxTarget) this.notesCheckboxTarget.checked = open
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

  // The card sits outside the results frame, so a search leaves it answering the previous
  // one. Gated on the address bar having moved, or the first results render would refetch
  // the chart the frame is already fetching. The src is the only record of the scope.
  reloadChart () {
    if (!this.hasChartFrameTarget || window.location.search === this.chartSearch) return
    const current = this.chartFrameTarget.getAttribute('src')
    if (!current) return
    this.chartSearch = window.location.search
    const scope = new URL(current, window.location.origin).searchParams.get('chart_scope')
    const url = new URL(window.location)
    url.searchParams.set('chart_only', '1')
    url.searchParams.set('chart_scope', scope || 'search')
    this.chartFrameTarget.setAttribute('src', url.toString())
  }
}
