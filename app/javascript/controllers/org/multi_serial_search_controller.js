import { Controller } from '@hotwired/stimulus'

/* global Turbo */

// Connects to data-controller='org--multi-serial-search'
export default class extends Controller {
  static targets = ['textarea', 'button', 'serialChips', 'results']
  static values = { url: String, emptyClass: String, successClass: String, grayClass: String, spinner: String }

  connect () {
    if (this.searching) return
    const serialsParam = new URL(window.location).searchParams.get('serials')
    if (serialsParam) {
      this.textareaTarget.value = serialsParam
      this.search(this.parseSerials(serialsParam))
    }
  }

  submit (event) {
    event.preventDefault()
    const serials = this.parseSerials(this.textareaTarget.value)
    if (!serials.length) return
    this.search(serials)
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
    window.history.pushState({}, '', url)

    this.resultsTarget.innerHTML = ''
    this.renderPlaceholderChips(serials)
    this.buttonTarget.disabled = true

    await Promise.all(serials.map((serial, index) => this.searchSerial(serial, index)))

    this.consolidateTables()
    this.buttonTarget.disabled = false
    this.searching = false
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

  async searchSerial (serial, index) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set('serial', serial)
    url.searchParams.set('chip_id', `chip_${index}`)

    const response = await fetch(url, {
      headers: { Accept: 'text/vnd.turbo-stream.html' }
    })

    if (response.ok) {
      Turbo.renderStreamMessage(await response.text())
      window.timeLocalizer?.localize()
    }
  }

  consolidateTables () {
    const results = Array.from(this.resultsTarget.querySelectorAll('.multi-search-serial-result'))
    const baseResult = results.find(r => r.querySelector('table'))
    if (!baseResult) return

    const baseTable = baseResult.querySelector('table')
    const tbody = baseTable.querySelector('tbody')
    const colCount = baseTable.querySelector('thead tr')?.children.length || 1

    results.forEach(result => {
      const serial = result.dataset.serial
      const count = result.dataset.count

      // Add serial header row
      const headerRow = document.createElement('tr')
      headerRow.className = 'tw:bg-gray-50 tw:dark:bg-gray-700'
      const headerCell = document.createElement('td')
      headerCell.colSpan = colCount
      headerCell.className = 'tw:px-3 tw:py-2 tw:text-sm tw:font-medium'
      headerCell.innerHTML = `Serial: <span class="serial-span">${serial}</span> <span class="tw:text-gray-500">— ${count} result${count === '1' ? '' : 's'}</span>`

      // Add close serials or no-match message for non-matching serials
      const noMatchMsg = result.querySelector('p')
      if (noMatchMsg) {
        headerCell.innerHTML += ` <span class="tw:text-gray-400">${noMatchMsg.innerHTML.trim()}</span>`
      }

      headerRow.appendChild(headerCell)
      tbody.appendChild(headerRow)

      // Move bike rows from this result's table into the shared tbody
      const table = result.querySelector('table')
      if (table && table !== baseTable) {
        table.querySelectorAll('tbody tr').forEach(row => tbody.appendChild(row))
      }
    })

    // Replace results with just the consolidated table wrapper
    const wrapper = baseTable.closest('.org-registration-search-component') || baseTable.parentElement
    this.resultsTarget.innerHTML = ''
    this.resultsTarget.appendChild(wrapper)
  }
}
