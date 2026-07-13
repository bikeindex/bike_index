import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global fetch, clearTimeout, setTimeout */

// Connects to data-controller='register--manufacturer-search'
//
// Typeahead for the manufacturer field on /register. Fetches matches from the
// autocomplete API; when nothing matches exactly, offers an "Add" row that
// keeps the typed name (the server self-reports it via manufacturer_other).
export default class extends Controller {
  static targets = ['input', 'menu', 'selfReportedNote']

  disconnect () {
    clearTimeout(this.debounceTimer)
  }

  search () {
    clearTimeout(this.debounceTimer)
    const query = this.inputTarget.value.trim()
    if (query === '') {
      this.hide()
      return
    }

    this.debounceTimer = setTimeout(() => this.fetchMatches(query), 200)
  }

  async fetchMatches (query) {
    const url = `/api/autocomplete?categories=frame_mnfg&per_page=10&q=${encodeURIComponent(query)}`
    const matches = await fetch(url)
      .then(response => response.json())
      .then(data => data.matches || [])
      .catch(() => [])

    // Ignore stale responses - only render if the query still matches the input
    if (query !== this.inputTarget.value.trim()) return

    this.renderMenu(query, matches)
  }

  renderMenu (query, matches) {
    const rows = matches.map(match => this.buildRow(match.text, () => this.pick(match.text)))

    const exactMatch = matches.some(match => match.text.toLowerCase() === query.toLowerCase())
    if (!exactMatch) {
      const addRow = this.buildRow(`Add “${query}” — not in our list`, () => this.pickSelfReported())
      addRow.classList.add('tw:border-t', 'tw:border-gray-100', 'tw:dark:border-gray-700', 'tw:font-semibold', 'tw:text-blue-600', 'tw:dark:text-blue-400')
      rows.push(addRow)
    }

    this.menuTarget.replaceChildren(...rows)
    collapse('show', this.menuTarget)
  }

  buildRow (text, onPick) {
    const row = document.createElement('button')
    row.type = 'button'
    row.textContent = text
    row.className = 'tw:block tw:w-full tw:cursor-pointer tw:px-3.5 tw:py-2.5 tw:text-left tw:text-sm tw:text-gray-700 tw:dark:text-gray-300 tw:hover:bg-gray-50 tw:dark:hover:bg-gray-700'
    // mousedown fires before the input's blur, so the pick isn't lost to hideSoon
    row.addEventListener('mousedown', (event) => {
      event.preventDefault()
      onPick()
    })
    return row
  }

  pick (name) {
    this.inputTarget.value = name
    this.hide()
    collapse('hide', this.selfReportedNoteTarget)
  }

  pickSelfReported () {
    this.hide()
    collapse('show', this.selfReportedNoteTarget)
  }

  hideSoon () {
    // Let a mousedown on a menu row run first
    setTimeout(() => this.hide(), 150)
  }

  hide () {
    collapse('hide', this.menuTarget)
  }
}
