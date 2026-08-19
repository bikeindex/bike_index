import { Controller } from '@hotwired/stimulus'
import TimeLocalizer from '@bikeindex/time-localizer'

/* global window */

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
    document.addEventListener('turbo:before-fetch-request', this.handleFetchRequest)
    document.addEventListener('turbo:before-fetch-response', this.handleFetchResponse)
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
    document.removeEventListener('turbo:before-fetch-request', this.handleFetchRequest)
    document.removeEventListener('turbo:before-fetch-response', this.handleFetchResponse)
    document.removeEventListener('turbo:fetch-request-error', this.handleFetchError)
    window.removeEventListener('search:rate-limited', this.showRateLimited)
    window.removeEventListener('popstate', this.handlePopstate)
    document.removeEventListener('click', this.handleRetryClick)
  }

  handleTurboLoad = () => {
    this.refreshResults()
  }

  submit () {
    this.formTarget.requestSubmit()
  }

  // Clear any stale loading state, then bring the results frame in line with the
  // address bar. Runs on initial connect and after every Turbo page load.
  refreshResults () {
    this.clearStaleFrameBusy()
    this.reloadFrameIfUrlStale()
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
    // Whatever the frame last asked for belongs to the entry we just left, so from
    // here it can't mean the frame is ahead of the address bar
    this.requestedURL = null
    const params = new URLSearchParams(window.location.search)
    ;['search_email', 'serial', 'search_notes'].forEach(name => {
      const input = this.formTarget.querySelector(`input[name="${name}"]`)
      if (input) input.value = params.get(name) || ''
    })
  }

  // A back/forward restoration can leave the results frame showing a snapshot for
  // a different query than the address bar (Turbo restores snapshots loosely by
  // path). Reload straight from the URL so results match; this loads from the
  // address bar, not the form, so it's immune to combobox/form restore races.
  reloadFrameIfUrlStale () {
    const frame = this.frameElement
    if (!this.differentSearchOnSamePage(frame?.getAttribute('src'), window.location.href)) return
    // Turbo advances the address bar only once a frame navigation has rendered, so a
    // frame already asking for a different search is ahead of the URL rather than
    // stale, and a turbo:load landing in that window would throw the rider's search away.
    if (this.differentSearchOnSamePage(this.requestedURL, window.location.href)) return

    frame.setAttribute('src', window.location.href)
  }

  // Two URLs asking the same search page for different results. Pairs on different
  // pages never reconcile, so they don't count: a back/forward restoration can
  // briefly leave one page's frame (eg marketplace_results_frame) in the DOM while
  // the address bar is another page (/search/registrations), and a frame response
  // that redirected elsewhere is still the one Turbo should render.
  differentSearchOnSamePage (url, otherUrl) {
    if (!url || !otherUrl) return false

    const first = new URL(url, window.location.origin)
    const second = new URL(otherUrl, window.location.origin)

    return first.pathname === second.pathname && first.search !== second.search
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
    const response = event.detail?.fetchResponse?.response

    if (response?.status === 429) {
      event.preventDefault() // stop Turbo's default handling of the throttled response
      this.showRateLimited()
      this.hideLoading() // drop the in-frame placeholder so it doesn't spin forever
    } else if (event.target === this.frameElement && this.frameResponseSuperseded(response?.url)) {
      event.preventDefault()
    }
  }

  // The frame's eager src fetch and a search submitted while it's still in flight
  // race each other. Turbo renders whichever lands last and rewrites history from
  // the frame, so the older response would drag the address bar back to the query
  // the rider searched away from.
  frameResponseSuperseded (url) {
    return this.differentSearchOnSamePage(url, this.requestedURL)
  }

  // What the frame is currently after. The frame's own src can't answer that: Turbo
  // assigns it before a src fetch, but for a form submit only once the response
  // arrives, so a submit in flight leaves src on the query being searched away from.
  handleFetchRequest = (event) => {
    if (!this.ownsFetch(event)) return

    this.requestedURL = event.detail?.url?.toString()
  }

  // Turbo targets the frame for its eager src fetch and the form for a submit;
  // anything else (the combobox raises these too) isn't ours.
  ownsFetch (event) {
    return event.target === this.frameElement || event.target === this.formTarget
  }

  // A fetch that rejects outright when the network drops never comes back with a
  // status, so handleFetchResponse never sees it and the spinner runs forever.
  handleFetchError = (event) => {
    if (!this.ownsFetch(event)) return

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
    if (this.failedSubmit) this.submit()
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
