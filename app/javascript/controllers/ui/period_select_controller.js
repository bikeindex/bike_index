import { Controller } from '@hotwired/stimulus'

// Submits the custom-range form by rebuilding the URL from window.location so
// non-period filters (e.g. search_email) survive — the form itself only carries
// start_time_selector / end_time_selector, so a default GET would drop them.
export default class extends Controller {
  static targets = ['startTime', 'endTime', 'customPeriod', 'customButton']

  // A chip is a search: it submits the form it belongs to, and leaves the custom panel it
  // replaces opening on the range it picked rather than wherever the panel was last left.
  rangePicked (event) {
    const radio = event.currentTarget
    // Its period reaches the same form as the chip's, and would outrank it
    if (this.hasCustomPeriodTarget) this.customPeriodTarget.disabled = true
    // The row renders outside the frame the search replaces, so nothing else unpicks it
    this.customButtonTarget.dataset.active = 'false'

    const { startTime, endTime } = radio.dataset
    if (startTime && this.hasStartTimeTarget) {
      this.startTimeTarget.value = startTime
      this.endTimeTarget.value = endTime
    }
    radio.form?.requestSubmit()
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
