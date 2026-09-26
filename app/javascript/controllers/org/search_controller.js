import { Controller } from '@hotwired/stimulus'
import { collapseField } from 'utils/collapse_utils'

/* global localStorage */

const RESULT_VIEW_KEY = 'orgRegistrationResultView'

// Connects to data-controller='org--search'
export default class extends Controller {
  static targets = ['perPage', 'optionalField', 'optionalFieldCheckbox', 'filterSummary', 'periodLabel', 'searchAll', 'searchAllHint', 'locationSearchHint']
  // What the results rendered as, so a stored preference knows whether it has anything to ask for
  static values = { resultView: String }

  connect () {
    this.initOptionalFields(0)
    this.syncLocationSearch(0)
    this.syncResultView()
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
    document.addEventListener('turbo:before-fetch-request', this.handleFetchRequest)
    window.addEventListener('search:results-failed', this.stopChartSpinner)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.handleFrameRender)
    document.removeEventListener('turbo:before-fetch-request', this.handleFetchRequest)
    window.removeEventListener('search:results-failed', this.stopChartSpinner)
  }

  // The column panel renders inside the results frame, but the chart is outside it - so it
  // fetches once the results land, from the address bar they moved.
  handleFrameRender = (event) => {
    this.syncResultView()
    this.syncPeriodLabel()
    this.syncLocationSearch()
    this.endSubmitSpinner()
    if (event.target === this.resultsFrame) this.reloadChart()
  }

  // The chart spins from the submit, though it waits for the results to fetch. A form
  // submit's target is the form, so the header is what names the frame. A hover's
  // prefetch isn't a search yet.
  handleFetchRequest = (event) => {
    const { headers } = event.detail.fetchOptions
    if (!headers['Turbo-Frame'] || headers['X-Sec-Purpose'] === 'prefetch') return
    if (headers['Turbo-Frame'] !== this.resultsFrame?.id) return
    const chart = this.searchChart
    if (!chart || this.chartParams(new URL(event.detail.url, window.location.href)) === this.chartShows(chart)) return
    chart.setAttribute('busy', '')
    this.chartAwaitingResults = true
  }

  // search--form shows the error; the chart stays on the search it has. Only the spinner
  // set above - Turbo marks the frame busy for its own fetches too.
  stopChartSpinner = () => {
    if (!this.chartAwaitingResults) return
    this.chartAwaitingResults = false
    this.chartFrame?.removeAttribute('busy')
  }

  // The view is the server's choice, so restoring the stored one means asking the frame
  // for it again - only when the address bar names no view, which every search and every
  // chip leaves it doing.
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

  // The notes and location fields, each named by data-field. One opens if an input in it has
  // a value, or if it was left open
  initOptionalFields (duration) {
    this.optionalFieldTargets.forEach(field => {
      const hasValue = [...field.querySelectorAll('input')].some(input => input.value.length > 0)
      const open = hasValue || localStorage.getItem(field.dataset.storageKey) === 'true'
      this.setOptionalField(field.dataset.field, open, duration)
    })
  }

  toggleOptionalField (event) {
    this.setOptionalField(event.target.dataset.field, event.target.checked)
  }

  setOptionalField (name, open, duration) {
    const field = this.optionalFieldTargets.find(target => target.dataset.field === name)
    if (!field) return
    collapseField(field, open, duration)
    localStorage.setItem(field.dataset.storageKey, String(open))
    const checkbox = this.optionalFieldCheckboxTargets.find(target => target.dataset.field === name)
    if (checkbox) checkbox.checked = open
  }

  // BikeServices::OrganizedSearch.location_searchable? - disabled, the fields hide and stop
  // submitting, but the checkbox keeps whether they were open
  syncLocationSearch (duration) {
    const checkbox = this.optionalFieldCheckboxTargets.find(target => target.dataset.field === 'location')
    const field = this.optionalFieldTargets.find(target => target.dataset.field === 'location')
    if (!checkbox || !field) return

    const status = document.querySelector('input[type=radio][name=search_status][form="Search_Form"]:checked')?.value
    const searchAll = this.hasSearchAllTarget && this.searchAllTarget.checked
    const searchable = JSON.parse(checkbox.dataset.locationableStatuses).includes(status) || (checkbox.dataset.regAddress === 'true' && !searchAll)

    checkbox.disabled = !searchable
    if (this.hasLocationSearchHintTarget) this.locationSearchHintTarget.hidden = searchable
    collapseField(field, searchable && checkbox.checked, duration)
  }

  // Bubbled from any field, so it picks out the one it's for
  emailChanged (event) {
    if (event.target.name !== 'search_email' || !this.hasSearchAllTarget) return
    const hasEmail = event.target.value.trim() !== ''
    this.searchAllTarget.disabled = hasEmail
    this.searchAllHintTarget.hidden = !hasEmail
    if (hasEmail && this.searchAllTarget.checked) {
      this.searchAllTarget.checked = false
      this.syncLocationSearch()
    }
  }

  filterChanged () {
    this.syncFilterSummary()
    // Before the submit, so a disabled location isn't searched
    this.syncLocationSearch()
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
  // one. Gated on the search itself having moved, or the first results render would refetch
  // the chart the frame is already fetching.
  reloadChart () {
    this.stopChartSpinner()
    const chart = this.searchChart
    if (!chart || this.chartParams() === this.chartShows(chart)) return
    chart.setAttribute('src', window.location.href)
  }

  // The chart frame, when its scope is the search - which the card says by rendering the
  // target. Switching scope navigates the frame itself, so the scope isn't part of a search.
  get searchChart () {
    const frame = this.chartFrame
    if (!frame?.getAttribute('src') || !frame.querySelector('[data-chart-follows-search]')) return null
    return frame
  }

  // What the chart is showing: its src is the record of it, holding the search the frame
  // last asked for, including one still in flight.
  chartShows (frame) {
    return this.chartParams(new URL(frame.getAttribute('src'), window.location.href))
  }

  // The same search, written by a link and by the address bar, differs in order and in
  // which empty fields it carries - so compare a canonical form. A page turn, a sort, a
  // per-page change or opening the card returns the same chart, so they're left out too.
  chartParams (url = window.location) {
    const params = new URLSearchParams(url.search);
    ['page', 'sort', 'sort_direction', 'direction', 'per_page', 'search_result_view', 'chart_open', 'chart_scope']
      .forEach(name => params.delete(name))

    return [...params].filter(([, value]) => value !== '').sort().join('&')
  }
}
