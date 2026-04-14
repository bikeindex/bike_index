import { Controller } from '@hotwired/stimulus'

/* global Turbo */

// Connects to data-controller='org--multi-serial-search'
export default class extends Controller {
  static targets = ['textarea', 'button', 'serialChips', 'results']
  static values = { url: String, emptyClass: String, successClass: String, grayClass: String, spinner: String }

  connect () {
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
    const url = new URL(window.location.pathname, window.location.origin)
    url.searchParams.set('serials', serials.join(','))
    window.history.pushState({}, '', url)

    this.resultsTarget.innerHTML = ''
    this.renderPlaceholderChips(serials)
    this.buttonTarget.disabled = true

    await Promise.all(serials.map((serial, index) => this.searchSerial(serial, index)))

    this.buttonTarget.disabled = false
  }

  renderPlaceholderChips (serials) {
    this.serialChipsTarget.innerHTML = serials.map((serial, index) =>
      `<span id="chip_${index}" class="${this.emptyClassValue}">${this.escapeHtml(serial)} ${this.spinnerValue}</span>`
    ).join('')
  }

  async searchSerial (serial, index) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set('serial', serial)
    url.searchParams.set('chip_id', `chip_${index}`)

    const response = await fetch(url, {
      headers: { Accept: 'text/vnd.turbo-stream.html' }
    })

    if (response.ok) {
      await Turbo.renderStreamMessage(await response.text())
      window.timeLocalizer?.localize()
    }
  }

  escapeHtml (text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
