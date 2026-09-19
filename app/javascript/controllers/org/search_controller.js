import { Controller } from '@hotwired/stimulus'

/* global localStorage */

// Connects to data-controller='org--search'
export default class extends Controller {
  static targets = ['perPage', 'notesField', 'notesCheckbox', 'chartFrame', 'filterSummary', 'periodLabel', 'searchAll', 'searchAllHint']

  connect () {
    this.chartSearch = this.chartParams()
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
    this.syncPeriodLabel()
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

  emailChanged (event) {
    if (!this.hasSearchAllTarget) return
    const hasEmail = event.target.value.trim() !== ''
    this.searchAllTarget.disabled = hasEmail
    if (hasEmail) this.searchAllTarget.checked = false
    this.searchAllHintTarget.hidden = !hasEmail
  }

  filterChanged () {
    this.syncFilterSummary()
    const form = document.getElementById('Search_Form')
    if (form) {
      form.requestSubmit()
    }
  }

  // Reads the chips' own markup rather than rebuilding their wording, so the summary can't
  // drift from the labels. An empty value (or `all`) is a group that isn't filtering.
  syncFilterSummary () {
    if (!this.hasFilterSummaryTarget) return
    const active = [...document.querySelectorAll('input[type=radio][form="Search_Form"]:checked')]
      .filter(radio => radio.value !== '' && radio.value !== 'all')
      .map(radio => radio.closest('label')?.querySelector('span')?.innerHTML)
      .filter(Boolean)

    this.filterSummaryTarget.innerHTML = active.join(' · ')
    this.filterSummaryTarget.hidden = active.length === 0
  }

  // The label sits outside the results frame the period buttons navigate. It reads the
  // button from the URL rather than its active state, which ui--period-select sets too.
  syncPeriodLabel () {
    const period = new URLSearchParams(window.location.search).get('period')
    const button = period && this.element.querySelector(`[data-period="${period}"]`)
    if (button && this.hasPeriodLabelTarget) {
      this.periodLabelTarget.textContent = button.textContent.replace(/\s+/g, ' ').trim()
    }
  }

  perPageChanged () {
    const url = new URL(window.location)
    url.searchParams.set('per_page', this.perPageTarget.value)
    url.searchParams.set('search_no_js', 'true')
    window.location = url.toString()
  }

  // The card sits outside the results frame, so a search leaves it answering the previous
  // one. Gated on the search itself having moved, or the first results render would refetch
  // the chart the frame is already fetching. The URL carries the scope, so it's the search.
  reloadChart () {
    if (!this.hasChartFrameTarget || this.chartParams() === this.chartSearch) return
    if (!this.chartFrameTarget.getAttribute('src')) return
    this.chartSearch = this.chartParams()
    this.chartFrameTarget.setAttribute('src', window.location.href)
  }

  // A page turn, a sort or a per-page change returns the same chart, so they don't count
  // as the address bar having moved.
  chartParams () {
    const params = new URLSearchParams(window.location.search);
    ['page', 'sort', 'sort_direction', 'direction', 'per_page'].forEach(name => params.delete(name))

    return params.toString()
  }
}
