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

    this.refreshResults()

    // Add timeLocalizer and watch for turbo-frame renders
    if (!window.timeLocalizer) window.timeLocalizer = new TimeLocalizer()
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
    // Re-run refreshResults after Turbo navigations: on back/forward, connect()
    // can fire before the frame is parsed, leaving the auto-submit un-run.
    document.addEventListener('turbo:load', this.handleTurboLoad)
    // Track whether a cross-document Turbo visit (eg a back/forward restoration)
    // is rendering, so reloadFrameFromUrl can stay out of its way. Cleared on any
    // render below so the flag can never stick on.
    document.addEventListener('turbo:visit', this.markTurboVisit)
    // The combobox swaps its non-JS query field for query_items[] on connect,
    // and it connects after this controller. Retry the auto-submit once it's
    // ready, otherwise a restored page submits the empty `query` field instead.
    document.addEventListener('search--combobox:connected', this.submitIfEmptyResults)
    // Same-document back/forward (a filter link advanced the URL without a
    // full page load) leaves the results frame's src stale. Re-point it at the
    // restored URL so the frame matches the address bar.
    window.addEventListener('popstate', this.reloadFrameFromUrl)
  }

  markTurboVisit = () => { this.turboVisitInProgress = true }

  // if the frame was loaded without results, submit the form
  submitIfEmptyResults = () => {
    // connect() and the turbo:load listener can both fire before the first
    // auto-submit's frame renders - so #loadedWithoutResults is still present on
    // the second call. Without this guard the duplicate requestSubmit is aborted
    // by Turbo (uncaught AbortError) and, once the first render flips
    // data-turbo-action to 'advance', pushes a history entry so the back button
    // no longer leaves the search page. Skip while a submit is already in flight.
    if (this.autoSubmitting) return
    if (!this.frameElement?.querySelector('#loadedWithoutResults')) return
    // Wait until the combobox has removed its non-JS `query` field (it fires
    // search--combobox:connected when done). Submitting first serializes the
    // empty `query` field instead of query_items[], so the URL drops the
    // selected items and stops matching the form.
    if (this.element.querySelector('[data-search--everything-combobox-target="nonjsfields"]')) return
    this.autoSubmitting = true
    // Use replace for the initial auto-submit so it doesn't add a duplicate history entry
    this.formTarget.setAttribute('data-turbo-action', 'replace')
    this.frameElement.addEventListener('turbo:frame-render', () => {
      this.formTarget.setAttribute('data-turbo-action', 'advance')
      this.autoSubmitting = false
    }, { once: true })
    this.formTarget.requestSubmit()
  }

  // Re-point the results frame at the restored URL after same-document history
  // navigation (a filter link advanced the URL without a full page load),
  // leaving the frame's src stale. A cross-document restoration instead starts a
  // Turbo visit that re-renders the whole page (and the turbo:load handler
  // re-runs the auto-submit), so re-pointing here would start a frame fetch the
  // body swap immediately aborts (uncaught AbortError) - skip it in that case.
  reloadFrameFromUrl = () => {
    if (this.turboVisitInProgress) return
    if (this.frameElement?.getAttribute('src')) {
      this.frameElement.setAttribute('src', window.location.href)
    }
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.handleFrameRender)
    document.removeEventListener('turbo:load', this.handleTurboLoad)
    document.removeEventListener('turbo:visit', this.markTurboVisit)
    document.removeEventListener('search--combobox:connected', this.submitIfEmptyResults)
    window.removeEventListener('popstate', this.reloadFrameFromUrl)
  }

  handleTurboLoad = () => {
    this.turboVisitInProgress = false
    this.refreshResults()
  }

  // Clear any stale loading state, then auto-submit if the loaded/restored frame
  // has no results yet. Runs on initial connect and after every Turbo page load.
  refreshResults () {
    this.clearStaleFrameBusy()
    this.submitIfEmptyResults()
  }

  // Turbo's [busy]/[aria-busy] loading state is transient, but a back/forward
  // snapshot can be cached mid-search and restored with busy stuck on - which
  // leaves the results frame hidden under the loading overlay forever. A real
  // search is a frame navigation (never fires turbo:load), so on load/connect
  // any busy on a [complete] frame is stale and safe to clear.
  clearStaleFrameBusy () {
    const frame = this.frameElement
    if (!frame?.hasAttribute('complete')) return
    frame.removeAttribute('busy')
    frame.removeAttribute('aria-busy')
  }

  handleFrameRender = () => {
    this.turboVisitInProgress = false
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
