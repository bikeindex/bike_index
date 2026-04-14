import { Controller } from '@hotwired/stimulus'

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

    this.buttonTarget.disabled = false
    this.searching = false
  }

  renderPlaceholderChips (serials) {
    this.serialChipsTarget.innerHTML = ''
    serials.forEach((serial, index) => {
      const chip = document.createElement('span')
      chip.id = `chip_${index}`
      chip.className = this.emptyClassValue
      chip.textContent = serial + ' '
      chip.insertAdjacentHTML('beforeend', this.spinnerValue)
      this.serialChipsTarget.appendChild(chip)
    })
  }

  async searchSerial (serial, index) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set('serial', serial)

    const response = await fetch(url, {
      headers: { Accept: 'text/vnd.turbo-stream.html' }
    })

    if (response.ok) {
      const html = await response.text()
      const template = document.createElement('template')
      template.innerHTML = html
      const streams = template.content.querySelectorAll('turbo-stream')
      streams.forEach(stream => {
        const target = document.getElementById(stream.getAttribute('target'))
        const content = stream.querySelector('template').content
        if (target && stream.getAttribute('action') === 'append') {
          target.appendChild(content.cloneNode(true))
        }
      })
      this.updateChip(index, serial)
      window.timeLocalizer?.localize()
    }
  }

  updateChip (index, serial) {
    const chip = document.getElementById(`chip_${index}`)
    if (!chip) return
    const hasResults = this.resultsTarget.querySelector(`[data-serial="${serial}"] table`)
    chip.className = hasResults ? this.successClassValue : this.grayClassValue
    chip.textContent = serial
  }

  escapeHtml (text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
