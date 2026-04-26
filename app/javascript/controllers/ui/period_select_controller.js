import { Controller } from '@hotwired/stimulus'

// Preserves current URL params when navigating via a period link or the
// custom-range form — period buttons are server-rendered, so their hrefs go
// stale after turbo-stream search updates pushState new params (e.g. search_email).
export default class extends Controller {
  select (event) {
    const link = event.currentTarget
    if (!link.href) return
    event.preventDefault()
    const linkUrl = new URL(link.href, window.location.origin)
    const newUrl = new URL(window.location.href)
    linkUrl.searchParams.forEach((value, key) => {
      newUrl.searchParams.set(key, value)
    })
    window.location.href = newUrl.pathname + newUrl.search
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
