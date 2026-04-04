import { Controller } from '@hotwired/stimulus'
import TimeLocalizer from '@bikeindex/time-localizer'

/* global window, CSS */

// Connects to data-controller='org--multi-serial-search'
export default class extends Controller {
  static targets = ['textarea', 'button', 'serialChips', 'results']
  static values = { url: String }

  connect () {
    if (!window.timeLocalizer) window.timeLocalizer = new TimeLocalizer()
  }

  async submit (event) {
    event.preventDefault()

    const text = this.textareaTarget.value.trim()
    if (!text) return

    const serials = [...new Set(
      text.split(/[,\n]/).map(s => s.trim()).filter(s => s)
    )]

    this.resultsTarget.innerHTML = ''
    this.renderChips(serials)
    this.buttonTarget.disabled = true

    for (const serial of serials) {
      await this.searchSerial(serial)
    }

    this.buttonTarget.disabled = false
  }

  renderChips (serials) {
    this.serialChipsTarget.innerHTML = serials.map(serial =>
      `<span class="tw:rounded tw:px-2 tw:py-1 tw:text-sm tw:bg-gray-100"
             data-serial-chip="${serial}">${this.escapeHtml(serial)}</span>`
    ).join('')
  }

  async searchSerial (serial) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set('serial', serial)

    const response = await fetch(url, {
      headers: {
        Accept: 'text/vnd.turbo-stream.html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })

    if (response.ok) {
      const html = await response.text()
      // Process turbo stream manually to append content
      const template = document.createElement('template')
      template.innerHTML = html
      const streams = template.content.querySelectorAll('turbo-stream')
      streams.forEach(stream => {
        const content = stream.querySelector('template').content
        this.resultsTarget.appendChild(content.cloneNode(true))
      })

      // Mark chip as matched or not
      const chip = this.serialChipsTarget.querySelector(`[data-serial-chip="${CSS.escape(serial)}"]`)
      if (chip) {
        const hasResults = this.resultsTarget.lastElementChild?.querySelector('table tbody tr')
        if (hasResults) {
          chip.classList.remove('tw:bg-gray-100')
          chip.classList.add('tw:bg-blue-500', 'tw:text-white')
        } else {
          chip.classList.add('tw:line-through')
        }
      }

      if (window.timeLocalizer) window.timeLocalizer.localize()
    }
  }

  escapeHtml (text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
