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
    // Remove search_no_js hidden field so submits go through the Turbo frame flow
    const noJsElement = this.element.querySelector('#search_no_js')
    if (noJsElement) noJsElement.remove()

    // The results frame eager-loads its own contents via its `src` (set
    // server-side once the page shell has rendered), so there's nothing to
    // submit here - just clear any stale loading state from a restored snapshot.
    this.clearStaleFrameBusy()

    // Add timeLocalizer and watch for turbo-frame renders
    if (!window.timeLocalizer) window.timeLocalizer = new TimeLocalizer()
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
    document.addEventListener('turbo:load', this.handleTurboLoad)
    // Track whether a cross-document Turbo visit (eg a back/forward restoration)
    // is rendering, so reloadFrameFromUrl can stay out of its way. Cleared on any
    // render below so the flag can never stick on.
    document.addEventListener('turbo:visit', this.markTurboVisit)
    // Same-document back/forward (a filter link advanced the URL without a
    // full page load) leaves the results frame's src stale. Re-point it at the
    // restored URL so the frame matches the address bar.
    window.addEventListener('popstate', this.reloadFrameFromUrl)
  }

  markTurboVisit = () => { this.turboVisitInProgress = true }

  // Re-point the results frame at the restored URL after same-document history
  // navigation (a filter link advanced the URL without a full page load),
  // leaving the frame's src stale. A cross-document restoration instead starts a
  // Turbo visit that re-renders the whole page (and re-eager-loads the frame), so
  // re-pointing here would start a frame fetch the body swap immediately aborts
  // (uncaught AbortError) - skip it in that case.
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
    window.removeEventListener('popstate', this.reloadFrameFromUrl)
  }

  handleTurboLoad = () => {
    this.turboVisitInProgress = false
    this.clearStaleFrameBusy()
  }

  // Turbo's [busy]/[aria-busy] loading state is transient, but a back/forward
  // snapshot can be cached mid-search and restored with busy stuck on - which
  // leaves the results frame hidden under the loading overlay forever. The frame
  // re-loads itself via its src, so on load/connect any busy on a [complete]
  // frame is stale and safe to clear.
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
