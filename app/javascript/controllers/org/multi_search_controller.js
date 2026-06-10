import { Controller } from '@hotwired/stimulus'

/* global Turbo, requestAnimationFrame */

// Connects to data-controller='org--multi-search'
export default class extends Controller {
  static targets = ['textarea', 'button', 'serialChips', 'results', 'searchAll']
  static values = { url: String, stickerUrl: String, searchKind: String, emptyClass: String, successClass: String, grayClass: String, errorClass: String, errorTooltip: String, spinner: String }

  connect () {
    if (this.searching) return
    const params = new URL(window.location).searchParams
    if (this.hasSearchAllTarget && params.get('search_all') === '1') {
      this.searchAllTarget.checked = true
    }
    const serialsParam = params.get('serials')
    if (serialsParam) {
      this.textareaTarget.value = serialsParam
      this.search(this.parseSerials(serialsParam))
    }
  }

  switchKind (event) {
    const value = event.target.value
    if (this.searchKindValue === value) return
    this.searchKindValue = value
    this.updatePlaceholderAndButton()
    this.resultsTarget.innerHTML = ''
    this.serialChipsTarget.innerHTML = ''

    const url = new URL(window.location.pathname, window.location.origin)
    url.searchParams.set('search_kind', value)
    window.history.pushState({}, '', url)
  }

  updatePlaceholderAndButton () {
    if (this.searchKindValue === 'stickers') {
      this.textareaTarget.placeholder = 'Enter multiple sticker codes, separated by commas or new lines'
      this.buttonTarget.textContent = 'Search stickers'
    } else {
      this.textareaTarget.placeholder = 'Enter multiple serial numbers, separated by commas or new lines'
      this.buttonTarget.textContent = 'Search serials'
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

  async search (serials) {
    this.searching = true
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

    this.resultsTarget.innerHTML = ''
    this.renderPlaceholderChips(serials)
    this.buttonTarget.disabled = true

    await Promise.all(serials.map((serial, index) => this.searchItem(serial, index)))

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

  alignTableColumns () {
    const tables = Array.from(this.resultsTarget.querySelectorAll('.org-registration-search-component table.ui-table'))
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

  sortAndFilterResults () {
    const results = Array.from(this.resultsTarget.querySelectorAll('.multi-search-serial-result'))
    results
      .sort((a, b) => parseInt(a.dataset.serialIndex) - parseInt(b.dataset.serialIndex))
      .forEach(result => {
        if (result.dataset.resultCount === '0') {
          result.remove()
        } else {
          this.resultsTarget.appendChild(result)
        }
      })
  }

  async searchItem (query, index) {
    if (this.searchKindValue === 'stickers') {
      return this.searchSticker(query, index)
    }
    return this.searchSerial(query, index)
  }

  async searchSerial (serial, index) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set('serial', serial)
    url.searchParams.set('chip_id', `chip_${index}`)
    if (this.searchAll) url.searchParams.set('search_all', '1')

    try {
      const response = await fetch(url, {
        headers: { Accept: 'text/vnd.turbo-stream.html' }
      })

      if (response.ok) {
        Turbo.renderStreamMessage(await response.text())
      } else {
        this.showChipError(serial, index, `Server error ${response.status}`)
      }
    } catch {
      this.showChipError(serial, index, 'Network error')
    }
  }

  async searchSticker (query, index) {
    const url = new URL(this.stickerUrlValue, window.location.origin)
    url.searchParams.set('query', query)
    url.searchParams.set('chip_id', `chip_${index}`)

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
