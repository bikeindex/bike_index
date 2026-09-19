import { Controller } from '@hotwired/stimulus'

// Submits the custom-range form by rebuilding the URL from window.location so
// non-period filters (e.g. search_email) survive — the form itself only carries
// start_time_selector / end_time_selector, so a default GET would drop them.
export default class extends Controller {
  connect () {
    document.addEventListener('turbo:frame-render', this.sync)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.sync)
  }

  // For buttons rendered outside the frame they navigate. A blank period is a search that
  // didn't change it.
  sync = () => {
    const period = new URLSearchParams(window.location.search).get('period')
    if (!period) return
    this.element.querySelectorAll('[data-period]').forEach(button => {
      button.dataset.active = String(button.dataset.period === period)
      button.classList.toggle('tw:opacity-60', period === 'custom')
    })
  }

  submit (event) {
    event.preventDefault()
    const form = event.currentTarget
    const startTime = form.querySelector('[name="start_time_selector"]')?.value
    const endTime = form.querySelector('[name="end_time_selector"]')?.value
    const newUrl = new URL(window.location.href)
    newUrl.searchParams.delete('start_time')
    newUrl.searchParams.delete('end_time')
    newUrl.searchParams.delete('timezone')
    newUrl.searchParams.set('period', 'custom')
    if (startTime) newUrl.searchParams.set('start_time', startTime)
    if (endTime) newUrl.searchParams.set('end_time', endTime)
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (tz) newUrl.searchParams.set('timezone', tz)
    window.location.href = newUrl.pathname + newUrl.search
  }
}
