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

    // Reveal the results frame's loading placeholder. It ships hidden so a no-JS
    // user never sees a spinner that can't resolve (the eager src needs JS); now
    // that JS is running, the eager fetch will load results, so show it.
    this.frameElement?.querySelector('[data-search-loading]')?.removeAttribute('hidden')

    // The results frame eager-loads its own contents via its `src` (set
    // server-side once the page shell has rendered), so there's nothing to
    // submit here - just reconcile a restored snapshot with the address bar.
    this.refreshResults()

    // Add timeLocalizer and watch for turbo-frame renders
    if (!window.timeLocalizer) window.timeLocalizer = new TimeLocalizer()
    document.addEventListener('turbo:frame-render', this.handleFrameRender)
    document.addEventListener('turbo:load', this.handleTurboLoad)
    // Surface throttling: the eager results frame and the kind-count fetch can
    // both come back 429 during active searching. Catch the frame's response
    // here; the count fetch signals via the search:rate-limited window event.
    document.addEventListener('turbo:before-fetch-response', this.handleFetchResponse)
    window.addEventListener('search:rate-limited', this.showRateLimited)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.handleFrameRender)
    document.removeEventListener('turbo:load', this.handleTurboLoad)
    document.removeEventListener('turbo:before-fetch-response', this.handleFetchResponse)
    window.removeEventListener('search:rate-limited', this.showRateLimited)
  }

  handleTurboLoad = () => {
    this.refreshResults()
  }

  // Clear any stale loading state, then bring the results frame in line with the
  // address bar. Runs on initial connect and after every Turbo page load.
  refreshResults () {
    this.clearStaleFrameBusy()
    this.reloadFrameIfUrlStale()
  }

  // A back/forward restoration can leave the results frame showing a snapshot for
  // a different query than the address bar (Turbo restores snapshots loosely by
  // path). Reload straight from the URL so results match; this loads from the
  // address bar, not the form, so it's immune to combobox/form restore races.
  reloadFrameIfUrlStale () {
    const frame = this.frameElement
    const src = frame?.getAttribute('src')
    if (!src) return
    if (new URL(src, window.location.origin).search !== window.location.search) {
      frame.setAttribute('src', window.location.href)
    }
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
    // A frame render means results came back, so clear any rate-limit notice
    this.hideRateLimited()
    // Run the time localization command on frame render
    if (window.timeLocalizer && typeof window.timeLocalizer.localize === 'function') {
      window.timeLocalizer.localize()
    }
    this.syncHiddenFieldsFromUrl()
  }

  // The results frame eager-loads via its src; on a 429 Turbo just logs and
  // leaves the spinner spinning. Take over the response so the user sees why.
  handleFetchResponse = (event) => {
    if (event.detail?.fetchResponse?.response?.status !== 429) return

    event.preventDefault() // stop Turbo's default handling of the throttled response
    this.showRateLimited()

    // Drop the in-frame loading placeholder so it doesn't spin forever
    this.frameElement?.querySelector('[data-search-loading]')?.setAttribute('hidden', '')
  }

  get rateLimitedElement () {
    return document.querySelector('[data-search-rate-limited]')
  }

  showRateLimited = () => {
    this.rateLimitedElement?.removeAttribute('hidden')
  }

  hideRateLimited () {
    this.rateLimitedElement?.setAttribute('hidden', '')
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
