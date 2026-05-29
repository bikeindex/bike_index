import { Controller } from '@hotwired/stimulus'
import TimeLocalizer from '@bikeindex/time-localizer'

/* global window  */

// Connects to data-controller='search--form'
export default class extends Controller {
  static targets = ['form']

  get frameElement () {
    const turboFrameId = this.formTarget.getAttribute('data-turbo-frame')

    return (document.getElementById(turboFrameId))
  }

  connect () {
    // Remove search_no_js hidden field
    const noJsElement = this.element.querySelector('#search_no_js')
    if (noJsElement) noJsElement.remove()

    this.submitIfEmptyResults()

    // Add timeLocalizer and watch for turbo-frame renders
    if (!window.timeLocalizer) window.timeLocalizer = new TimeLocalizer()
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
    // Re-check after Turbo navigations: on back/forward, connect() can fire
    // before the frame element is parsed, leaving #loadedWithoutResults in
    // place with no auto-submit.
    document.addEventListener('turbo:load', this.submitIfEmptyResults)
    // Same-document back/forward (a filter link advanced the URL without a
    // full page load) leaves the results frame's src stale. Re-point it at the
    // restored URL so the frame matches the address bar.
    window.addEventListener('popstate', this.reloadFrameFromUrl)
  }

  // if the frame was loaded without results, submit the form
  submitIfEmptyResults = () => {
    // connect() and the turbo:load listener can both fire before the first
    // auto-submit's frame renders. Without this guard the second call submits
    // again, and once the first render flips data-turbo-action to 'advance' the
    // duplicate submit pushes a history entry - so the back button no longer
    // leaves the search page. Skip while an auto-submit is already in flight.
    if (this.autoSubmitting) return
    if (!this.frameElement?.querySelector('#loadedWithoutResults')) return
    this.autoSubmitting = true
    // Use replace for the initial auto-submit so it doesn't add a duplicate history entry
    this.formTarget.setAttribute('data-turbo-action', 'replace')
    this.frameElement.addEventListener('turbo:frame-render', () => {
      this.formTarget.setAttribute('data-turbo-action', 'advance')
      this.autoSubmitting = false
    }, { once: true })
    this.formTarget.requestSubmit()
  }

  // Only fires for same-document history navigation; cross-document back/forward
  // re-renders the page and submitIfEmptyResults handles it instead.
  reloadFrameFromUrl = () => {
    if (this.frameElement?.getAttribute('src')) {
      this.frameElement.setAttribute('src', window.location.href)
    }
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.handleFrameRender)
    document.removeEventListener('turbo:load', this.submitIfEmptyResults)
    window.removeEventListener('popstate', this.reloadFrameFromUrl)
  }

  handleFrameRender = () => {
    // Run the time localization command on frame render
    if (window.timeLocalizer && typeof window.timeLocalizer.localize === 'function') {
      window.timeLocalizer.localize()
    }
    this.syncHiddenFieldsFromUrl()
  }

  // The form sits outside the results frame, so frame-nav period clicks advance
  // the URL but leave its hidden fields stale. Sync from the URL so the next
  // submit doesn't drop the period the user just chose.
  syncHiddenFieldsFromUrl () {
    const params = new URLSearchParams(window.location.search)
    this.formTarget.querySelectorAll('input[type="hidden"]').forEach(input => {
      // Skip array fields (eg query_items[]) - the combobox owns those, and
      // URLSearchParams.get would collapse them all to the first value
      if (!input.name || input.name.endsWith('[]') || !params.has(input.name)) return
      const newValue = params.get(input.name)
      if (input.value !== newValue) input.value = newValue
    })
  }
}
