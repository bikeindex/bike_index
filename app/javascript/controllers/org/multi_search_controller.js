import { Controller } from '@hotwired/stimulus'

/* global Turbo, requestAnimationFrame */

// A long paste would otherwise open one request per serial at once
const MAX_CONCURRENT_SEARCHES = 6

// Connects to data-controller='org--multi-search'
export default class extends Controller {
  static targets = ['textarea', 'button', 'serialChips', 'results', 'searchAll', 'searchAllHint']
  static values = { url: String, searchKind: String, serialsPlaceholder: String, stickersPlaceholder: String, serialsButton: String, stickersButton: String, emptyClass: String, successClass: String, grayClass: String, errorClass: String, errorTooltip: String, spinner: String }

  connect () {
    if (this.searching) return
    this.onPopState = () => this.syncFromUrl()
    window.addEventListener('popstate', this.onPopState)
    // Renders disabled: clicking before connect submits the form and reloads
    this.buttonTarget.disabled = false
    this.syncFromUrl({ preserveInput: true })
  }

  disconnect () {
    window.removeEventListener('popstate', this.onPopState)
  }

  // Restore the form + results from the URL, on initial load and on back/forward.
  // The URL already reflects this state, so don't push another history entry.
  syncFromUrl ({ preserveInput = false } = {}) {
    const params = new URL(window.location).searchParams
    const kind = params.get('search_kind') === 'stickers' ? 'stickers' : 'serials'
    if (this.searchKindValue !== kind) this.applyKind(kind)
    if (this.hasSearchAllTarget && !this.searchAllTarget.disabled) {
      this.searchAllTarget.checked = params.get('search_all') === '1'
    }
    this.syncSearchAll()
    const serialsParam = params.get('serials') || ''
    // On connect, keep anything typed while the controller was still loading
    if (!preserveInput || serialsParam) this.textareaTarget.value = serialsParam
    const serials = this.parseSerials(serialsParam)
    if (serials.length) {
      this.search(serials, { pushHistory: false })
    } else {
      this.resultsTarget.innerHTML = ''
      this.serialChipsTarget.innerHTML = ''
    }
  }

  switchKind (event) {
    const value = event.target.value
    if (this.searchKindValue === value) return
    this.applyKind(value)
    this.resultsTarget.innerHTML = ''
    this.serialChipsTarget.innerHTML = ''

    const url = new URL(window.location.pathname, window.location.origin)
    url.searchParams.set('search_kind', value)
    window.history.pushState({}, '', url)
  }

  applyKind (kind) {
    this.searchKindValue = kind
    this.updatePlaceholderAndButton()
    const radio = this.element.querySelector(`input[name='search_kind'][value='${kind}']`)
    if (radio) radio.checked = true
    this.syncSearchAll()
  }

  updatePlaceholderAndButton () {
    this.textareaTarget.placeholder = this[`${this.searchKindValue}PlaceholderValue`]
    this.buttonTarget.textContent = this[`${this.searchKindValue}ButtonValue`]
  }

  // Sticker search always spans every organization, so lock "search all" on while it's active
  syncSearchAll () {
    if (!this.hasSearchAllTarget) return
    if (this.searchKindValue === 'stickers') {
      this.searchAllTarget.checked = true
      this.searchAllTarget.disabled = true
      if (this.hasSearchAllHintTarget) this.searchAllHintTarget.classList.remove('tw:hidden')
    } else if (this.searchAllTarget.disabled) {
      this.searchAllTarget.checked = false
      this.searchAllTarget.disabled = false
      if (this.hasSearchAllHintTarget) this.searchAllHintTarget.classList.add('tw:hidden')
    }
  }

  submit (event) {
    event.preventDefault()
    const serials = this.parseSerials(this.textareaTarget.value)
    if (!serials.length) return
    this.search(serials)
  }

  get searchAll () {
    return this.hasSearchAllTarget && this.searchAllTarget.checked
  }

  parseSerials (text) {
    return [...new Set(
      text.split(/[,\n]/).map(s => s.trim()).filter(s => s)
    )]
  }

  async search (serials, { pushHistory = true } = {}) {
    this.searching = true
    if (pushHistory) {
      const url = new URL(window.location.pathname, window.location.origin)
      url.searchParams.set('serials', serials.join(','))
      if (this.searchKindValue === 'stickers') {
        url.searchParams.set('search_kind', 'stickers')
      }
      if (this.searchAll) {
        url.searchParams.set('search_all', '1')
      } else {
        url.searchParams.delete('search_all')
      }
      window.history.pushState({}, '', url)
    }

    this.resultsTarget.innerHTML = ''
    this.renderPlaceholderChips(serials)
    this.buttonTarget.disabled = true

    await this.searchAllItems(serials)

    // Wait a frame for Turbo stream DOM updates to complete
    await new Promise(resolve => requestAnimationFrame(resolve))
    this.sortAndFilterResults()
    // Trigger column toggle to apply stored column visibility to new tables
    this.element.dispatchEvent(new Event('turbo:frame-render', { bubbles: true }))
    this.alignTableColumns()
    window.timeLocalizer?.localize()
    this.buttonTarget.disabled = false
    this.searching = false
  }

  async searchAllItems (serials) {
    for (let start = 0; start < serials.length; start += MAX_CONCURRENT_SEARCHES) {
      await Promise.all(serials.slice(start, start + MAX_CONCURRENT_SEARCHES)
        .map((serial, offset) => this.searchItem(serial, start + offset)))
    }
  }

  alignTableColumns () {
    const tables = Array.from(this.resultsTarget.querySelectorAll('.multi-search-serial-result table.ui-table'))
    if (tables.length < 2) return

    tables.forEach(table => {
      table.querySelectorAll('thead th').forEach(th => { th.style.minWidth = '' })
    })

    const maxWidths = []
    tables.forEach(table => {
      table.querySelectorAll('thead th').forEach((th, i) => {
        if (th.offsetWidth > (maxWidths[i] || 0)) maxWidths[i] = th.offsetWidth
      })
    })

    tables.forEach(table => {
      table.querySelectorAll('thead th').forEach((th, i) => {
        if (maxWidths[i]) th.style.minWidth = `${maxWidths[i]}px`
      })
    })
  }

  renderPlaceholderChips (serials) {
    this.serialChipsTarget.innerHTML = ''
    serials.forEach((serial, index) => {
      const chip = document.createElement('span')
      chip.id = `chip_${index}`
      chip.className = this.emptyClassValue
      chip.appendChild(this.serialSpan(serial))
      chip.insertAdjacentHTML('beforeend', this.spinnerValue)
      this.serialChipsTarget.appendChild(chip)
    })
  }

  serialSpan (serial) {
    const span = document.createElement('span')
    span.className = 'serial-span tw:mr-3'
    span.textContent = serial.toUpperCase()
    return span
  }

  // Drop results the component flagged empty (no exact matches and no close serials).
  sortAndFilterResults () {
    const results = Array.from(this.resultsTarget.querySelectorAll('.multi-search-serial-result'))
    results
      .sort((a, b) => parseInt(a.dataset.serialIndex) - parseInt(b.dataset.serialIndex))
      .forEach(result => {
        if (result.dataset.hasResults === 'true') {
          this.resultsTarget.appendChild(result)
        } else {
          result.remove()
        }
      })
  }

  async searchItem (query, index) {
    const stickers = this.searchKindValue === 'stickers'
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set(stickers ? 'query' : 'serial', query)
    url.searchParams.set('chip_id', `chip_${index}`)
    if (stickers) {
      url.searchParams.set('search_kind', 'stickers')
    } else if (this.searchAll) {
      url.searchParams.set('search_all', '1')
    }

    try {
      const response = await fetch(url, {
        headers: { Accept: 'text/vnd.turbo-stream.html' }
      })

      if (response.ok) {
        Turbo.renderStreamMessage(await response.text())
      } else {
        this.showChipError(query, index, `Server error ${response.status}`)
      }
    } catch {
      this.showChipError(query, index, 'Network error')
    }
  }

  showChipError (serial, index, message) {
    const chip = document.getElementById(`chip_${index}`)
    if (!chip) return
    chip.className = this.errorClassValue
    chip.innerHTML = ''
    chip.appendChild(this.serialSpan(serial))
    chip.insertAdjacentHTML('beforeend', this.errorTooltipValue.replace('__MESSAGE__', message))
  }
}
