import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global localStorage */

// Connects to data-controller='org--search'
export default class extends Controller {
  static targets = ['filters', 'filtersButton', 'columns', 'columnsButton', 'perPage',
    'exportLink', 'notesField', 'notesCheckbox', 'chartFrame']

  static PANELS = ['filters', 'columns']

  connect () {
    this.restorePanels()
    this.initNotesSearch()
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.handleFrameRender)
  }

  // null wherever the page renders one panel but not the other - the multi-search and the
  // bike page both show the column toggle with no search filters beside it
  panel (name) {
    const present = name === 'filters' ? this.hasFiltersTarget : this.hasColumnsTarget
    if (!present) return null

    return {
      key: `orgRegistration${name === 'filters' ? 'Filters' : 'Columns'}Open`,
      element: name === 'filters' ? this.filtersTarget : this.columnsTarget,
      button: this.panelButton(name)
    }
  }

  panelButton (name) {
    if (name === 'filters') return this.hasFiltersButtonTarget ? this.filtersButtonTarget : null
    return this.hasColumnsButtonTarget ? this.columnsButtonTarget : null
  }

  // The column panel and the chart both render inside frames the search replaces, so their
  // state has to be put back on every response rather than only on connect
  handleFrameRender = (event) => {
    if (this.hasChartFrameTarget && event.target === this.chartFrameTarget) return
    this.updateExportLink()
    this.restorePanels()
    this.reloadChart()
  }

  toggleFilters () {
    this.togglePanel('filters')
  }

  toggleColumns () {
    this.togglePanel('columns')
  }

  restorePanels () {
    this.constructor.PANELS.map(name => this.panel(name)).filter(Boolean).forEach(panel => {
      const open = localStorage.getItem(panel.key) === 'true'
      if (open) collapse('show', panel.element, 0)
      this.setButtonState(panel, open)
    })
  }

  togglePanel (name) {
    const panel = this.panel(name)
    if (!panel) return
    const wasHidden = panel.element.classList.contains('tw:hidden!') ||
      panel.element.classList.contains('tw:hidden')
    collapse('toggle', panel.element)
    localStorage.setItem(panel.key, wasHidden ? 'true' : 'false')
    this.setButtonState(panel, wasHidden)
  }

  // data-active drives UI::Button's active styling, aria-expanded the disclosure semantics
  setButtonState (panel, open) {
    if (!panel.button) return
    panel.button.dataset.active = String(open)
    panel.button.setAttribute('aria-expanded', String(open))
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
  // one. Its own scope survives: the frame's src is the only place that's recorded.
  reloadChart () {
    if (!this.hasChartFrameTarget) return
    const current = this.chartFrameTarget.getAttribute('src')
    if (!current) return
    const scope = new URL(current, window.location.origin).searchParams.get('chart_scope')
    const url = new URL(window.location)
    url.searchParams.set('chart_only', '1')
    url.searchParams.set('chart_scope', scope || 'search')
    this.chartFrameTarget.setAttribute('src', url.toString())
  }
}
