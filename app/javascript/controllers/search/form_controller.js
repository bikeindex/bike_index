import { Controller } from '@hotwired/stimulus'
import TimeLocalizer from '@bikeindex/time-localizer'

/* global window, Date */

// Record back/forward navigations at module scope: the popstate that re-enters a
// search page fires before the controller reconnects, so a controller-scoped
// listener would miss it. reloadRestoredFrame uses this to tell a restoration
// (popstate, eager frame restored empty) from a link visit (turbo:before-visit,
// frame fills itself).
window.addEventListener('popstate', () => { window.searchLastPopAt = Date.now() })

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
    this.showLoading()

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
    document.addEventListener('turbo:before-visit', this.handleBeforeVisit)
    document.addEventListener('turbo:fetch-request-error', this.handleFetchError)
    window.addEventListener('search:rate-limited', this.showRateLimited)
    window.addEventListener('popstate', this.handlePopstate)
    // The results frame renders outside this controller's element, so its retry
    // button can't reach us by data-action
    document.addEventListener('click', this.handleRetryClick)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-render', this.handleFrameRender)
    document.removeEventListener('turbo:load', this.handleTurboLoad)
    document.removeEventListener('turbo:before-fetch-response', this.handleFetchResponse)
    document.removeEventListener('turbo:before-visit', this.handleBeforeVisit)
    document.removeEventListener('turbo:fetch-request-error', this.handleFetchError)
    window.removeEventListener('search:rate-limited', this.showRateLimited)
    window.removeEventListener('popstate', this.handlePopstate)
    document.removeEventListener('click', this.handleRetryClick)
  }

  handleTurboLoad = () => {
    this.refreshResults()
  }

  // Link/programmatic visits (period & chart links) fire this; history navigation
  // does not. Stamp it so reloadRestoredFrame can skip a frame the visit is
  // already filling.
  handleBeforeVisit = () => {
    window.searchLastVisitAt = Date.now()
    clearTimeout(this.emptyReloadTimer)
  }

  // Clear any stale loading state, then bring the results frame in line with the
  // address bar. Runs on initial connect and after every Turbo page load.
  refreshResults () {
    clearTimeout(this.emptyReloadTimer) // a new page load supersedes any pending poll
    this.clearStaleFrameBusy()
    this.reloadFrameIfUrlStale()
    this.reloadRestoredFrame()
  }

  // The visible text filters live outside the results frame, so a back/forward
  // that only reloads the frame (the form's DOM isn't re-rendered) leaves them
  // showing the previous query while the results below match a different URL.
  // Reconcile them from the address bar. Bound to popstate, which fires only on
  // history navigation -- never on a link/form search -- so it can't revert what
  // the user is typing; a full-page restoration re-renders the form from the
  // server instead, so missing those (the controller reconnects after the
  // popstate) is harmless.
  handlePopstate = () => {
    const params = new URLSearchParams(window.location.search)
    ;['search_email', 'serial', 'search_notes'].forEach(name => {
      const input = this.formTarget.querySelector(`input[name="${name}"]`)
      if (input) input.value = params.get(name) || ''
    })
  }

  // Turbo doesn't cache the eager results frame's contents and won't re-fetch a
  // [complete] frame, so on a back/forward it comes back empty. Re-fetch its src
  // so results reappear, like a real browser's BFCache restore.
  //
  // Scoped to a recent popstate that no link visit (turbo:before-visit) has
  // superseded, so it never disturbs a search submit or a period/chart click.
  // Restoration finalizes a tick or two after the load and can clobber an early
  // reload, so retry until content sticks; handleFrameRender cancels it once it
  // lands.
  reloadRestoredFrame (attempt = 0) {
    // Suppress only when a link visit is the most recent navigation (it fills the
    // frame itself); a back/forward popstate, or the initial load, proceeds.
    if ((window.searchLastPopAt || 0) < (window.searchLastVisitAt || 0)) return
    const frame = this.frameElement
    const src = frame?.getAttribute('src')
    if (!src) return
    if (frame.childElementCount > 0) return // populated - done
    if (attempt >= 20) return // give up after ~2s rather than loop on a truly empty result
    if (frame.hasAttribute('complete')) {
      frame.removeAttribute('complete') // Turbo skips re-fetching a [complete] frame
      frame.setAttribute('src', src)
    }
    this.emptyReloadTimer = setTimeout(() => this.reloadRestoredFrame(attempt + 1), 100)
  }

  // A back/forward restoration can leave the results frame showing a snapshot for
  // a different query than the address bar (Turbo restores snapshots loosely by
  // path). Reload straight from the URL so results match; this loads from the
  // address bar, not the form, so it's immune to combobox/form restore races.
  reloadFrameIfUrlStale () {
    const frame = this.frameElement
    const src = frame?.getAttribute('src')
    if (!src) return
    const srcUrl = new URL(src, window.location.origin)
    // Only reconcile within the same search page. A back/forward restoration can
    // briefly leave one page's frame (eg marketplace_results_frame) in the DOM
    // while the address bar is another page (/search/registrations); pointing the
    // frame there fetches a response without that frame, which Turbo discards.
    if (srcUrl.pathname !== window.location.pathname) return
    if (srcUrl.search !== window.location.search) {
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
    // Content landed, so a pending restore-reload poll is done.
    if (this.frameElement?.childElementCount > 0) clearTimeout(this.emptyReloadTimer)
    // A frame render means results came back, so clear any failure notice
    this.hideNotices()
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
    this.hideLoading()
  }

  // A fetch that rejects outright when the network drops never comes back with a
  // status, so handleFetchResponse never sees it and the spinner runs forever.
  // Turbo targets the frame for its eager src fetch and the form for a submit;
  // anything else (the combobox raises this too) isn't ours.
  handleFetchError = (event) => {
    if (event.target !== this.frameElement && event.target !== this.formTarget) return

    // A failed submit has to be retried by re-submitting: the frame's src still
    // points at the previous query, so reloading it would show the old results.
    this.failedSubmit = event.target === this.formTarget
    this.hideLoading()
    this.showNotice('fetch-failed')
  }

  handleRetryClick = (event) => {
    if (event.target.closest('[data-search-retry]')) this.retryResults()
  }

  retryResults = () => {
    this.hideNotices()
    this.showLoading()
    if (this.failedSubmit) this.formTarget.requestSubmit()
    else this.frameElement?.reload()
  }

  get loadingElement () {
    return this.frameElement?.querySelector('[data-search-loading]')
  }

  showLoading () {
    this.loadingElement?.removeAttribute('hidden')
  }

  hideLoading () {
    this.loadingElement?.setAttribute('hidden', '')
  }

  // The notices render beside the results frame, outside this controller's element
  showNotice (name) {
    document.querySelector(`[data-search-notice="${name}"]`)?.removeAttribute('hidden')
  }

  hideNotices () {
    document.querySelectorAll('[data-search-notice]')
      .forEach(element => element.setAttribute('hidden', ''))
  }

  showRateLimited = () => this.showNotice('rate-limited')

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
