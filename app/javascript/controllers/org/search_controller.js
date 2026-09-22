import { Controller } from '@hotwired/stimulus'

/* global localStorage */

const RESULT_VIEW_KEY = 'orgRegistrationResultView'

// Connects to data-controller='org--search'
export default class extends Controller {
  static targets = ['perPage', 'optionalField', 'optionalFieldCheckbox', 'filterSummary', 'periodLabel', 'searchAll', 'searchAllHint']
  // What the results rendered as, so a stored preference knows whether it has anything to ask for
  static values = { resultView: String }

  connect () {
    this.chartSearch = this.chartParams()
    this.initOptionalFields()
    this.syncResultView()
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.handleFrameRender)
  }

  // The column panel and the chart render inside frames the search replaces. The panel
  // looks after itself - ui--collapse reconnects with it - but the chart is outside them.
  handleFrameRender = (event) => {
    this.syncResultView()
    this.syncPeriodLabel()
    this.endSubmitSpinner()
    if (event.target === this.chartFrame) return
    this.reloadChart()
  }

  // Spreadsheet or thumbnail is the server's choice, so restoring the stored one means
  // asking the frame for it again - only when the address bar names no view, which every
  // search and every chip leaves it doing.
  syncResultView () {
    const params = new URLSearchParams(window.location.search)
    const inUrl = params.get('search_result_view')
    if (inUrl) return localStorage.setItem(RESULT_VIEW_KEY, inUrl)

    const stored = localStorage.getItem(RESULT_VIEW_KEY)
    const frame = this.resultsFrame
    if (!stored || stored === this.resultViewValue || !frame) return

    params.set('search_result_view', stored)
    const url = `${window.location.pathname}?${params}`
    // The address bar moves first, so search--form doesn't read the two as out of step.
    // Replacing rather than pushing: the rider didn't navigate here.
    window.history.replaceState(window.history.state, '', url)
    frame.setAttribute('src', url)
  }

  // Pages::Org::Search::ChartCard::FRAME_ID - the card also renders where there's no org--search
  get chartFrame () {
    return this.element.querySelector('turbo-frame#chart_card_frame')
  }

  // Pages::SearchResults::Frame's, which the loading overlay's CSS reaches the same way
  get resultsFrame () {
    return this.element.querySelector('.search-results-frame-wrapper > turbo-frame')
  }

  // The notes and location fields, each named by data-field. One opens with a value in it,
  // or if it was left open
  initOptionalFields () {
    this.optionalFieldTargets.forEach(field => {
      const hasValue = [...field.querySelectorAll('input[type=text]')].some(input => input.value.length > 0)
      if (hasValue || localStorage.getItem(this.optionalFieldKey(field.dataset.field)) === 'true') {
        this.setOptionalField(field.dataset.field, true)
      }
    })
  }

  toggleOptionalField (event) {
    this.setOptionalField(event.target.dataset.field, event.target.checked)
  }

  setOptionalField (name, open) {
    const field = this.optionalFieldTargets.find(target => target.dataset.field === name)
    if (!field) return
    field.classList.toggle('tw:hidden', !open)
    localStorage.setItem(this.optionalFieldKey(name), String(open))
    const checkbox = this.optionalFieldCheckboxTargets.find(target => target.dataset.field === name)
    if (checkbox) checkbox.checked = open
  }

  optionalFieldKey (name) {
    return `orgRegistration${name.charAt(0).toUpperCase()}${name.slice(1)}SearchOpen`
  }

  // Bubbled from any field, so it picks out the one it's for
  emailChanged (event) {
    if (event.target.name !== 'search_email' || !this.hasSearchAllTarget) return
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
      // The row above the summary names the date range itself
      .filter(radio => radio.name !== 'period')
      .filter(radio => radio.value !== '' && radio.value !== 'all')
      .map(radio => radio.closest('label')?.querySelector('span')?.innerHTML)
      .filter(Boolean)

    this.filterSummaryTarget.innerHTML = active.join(' · ')
    this.filterSummaryTarget.hidden = active.length === 0
  }

  // The chip the summary leaves out, for the same reason it reads the others' markup.
  // ui--period-select owns the submit, so this runs off the search it came back from.
  // Its text, not the span the summary reuses: the server's own label carries the prefix
  // that the chip hides below md.
  syncPeriodLabel () {
    const picked = document.querySelector('input[type=radio][name=period][form="Search_Form"]:checked')
    if (!this.hasPeriodLabelTarget || !picked) return

    this.periodLabelTarget.textContent = picked.closest('label').textContent.replace(/\s+/g, ' ').trim()
  }

  // The search submits into a frame, so the page it spun on is still here - register--retry
  // raises the same event for a submit that ended without going anywhere
  endSubmitSpinner () {
    const form = document.getElementById('Search_Form')
    if (!form) return

    ;[...form.elements].filter(element => element.type === 'submit')
      .forEach(element => element.dispatchEvent(new Event('spinner:reset')))
  }

  perPageChanged () {
    const url = new URL(window.location)
    url.searchParams.set('per_page', this.perPageTarget.value)
    url.searchParams.set('search_no_js', 'true')
    window.location = url.toString()
  }

  // The card sits outside the results frame, so a search leaves it answering the previous
  // one - when its scope is the search, which the card says by rendering the target. Gated
  // on the search itself having moved, or the first results render would refetch the chart
  // the frame is already fetching. The URL carries the scope, so it's the search.
  reloadChart () {
    const frame = this.chartFrame
    if (!frame?.querySelector('[data-chart-follows-search]')) return
    if (this.chartParams() === this.chartSearch) return
    if (!frame.getAttribute('src')) return
    this.chartSearch = this.chartParams()
    frame.setAttribute('src', window.location.href)
  }

  // A page turn, a sort, a per-page change or opening the card itself returns the same
  // chart, so they don't count as the address bar having moved.
  chartParams () {
    const params = new URLSearchParams(window.location.search);
    ['page', 'sort', 'sort_direction', 'direction', 'per_page', 'search_result_view', 'chart_open']
      .forEach(name => params.delete(name))

    return params.toString()
  }
}
