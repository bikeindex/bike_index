import { Controller } from '@hotwired/stimulus'

/* global Turbo, requestAnimationFrame */

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

    // Wait a frame for Turbo stream DOM updates to complete
    await new Promise(resolve => requestAnimationFrame(resolve))
    this.sortAndFilterResults()
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
}
