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

  // Moves the matching radio in the settings panel rather than submitting a second field of
  // the same name. A hidden field (propulsion_type) has no group, so it clears instead.
  //
  // The chip's own state is set here too: the form renders outside the results frame, so a
  // frame search never brings back a fresh one to carry it.
  toggleQuickFilter (event) {
    const chip = event.currentTarget
    const { quickFilterName: name, quickFilterValue: value } = chip.dataset
    const radios = [...document.querySelectorAll(`input[type=radio][name="${name}"]`)]
    let active

    if (radios.length) {
      const target = radios.find(radio => radio.value === value)
      if (!target) return
      const reset = radios.find(radio => radio.value === '' || radio.value === 'all') || target
      active = !target.checked
      ;(active ? target : reset).checked = true
    } else {
      const input = document.querySelector(`#Search_Form input[name="${name}"]`)
      if (!input) return
      active = input.value !== value
      input.value = active ? value : ''
    }

    chip.dataset.active = active ? 'true' : ''
    chip.setAttribute('aria-pressed', String(active))
    this.filterChanged()
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
