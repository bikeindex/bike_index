import '@hotwired/turbo-rails'

// Import stimulus controllers
import { Application } from '@hotwired/stimulus'
// Lazy load all controllers
import { lazyLoadControllersFrom } from '@hotwired/stimulus-loading'

import TimeLocalizer from '@bikeindex/time-localizer'

// Fixes for hotwire_combobox 0.4.1's option lookup, Enter handling and typing over a selection
import 'utils/hw_combobox_patch'

/* global Turbo */
// Disable Turbo by default, only enable on case-by-case
// You must include data-turbo="true" on the elements you want to enable turbo on
Turbo.session.drive = false
const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application
lazyLoadControllersFrom('controllers', application)

function localizeTime () {
  if (!window.timeLocalizer) window.timeLocalizer = new TimeLocalizer()
  window.timeLocalizer.localize()
}

// A fetch still in flight when the page goes away rejects with a generic network
// error, not an AbortError, so the message alone can't separate it from real
// breakage - only treat these phrasings as noise while we're actually leaving.
const NAVIGATION_FETCH_ERROR = /Failed to fetch|Load failed|Fetch is aborted|aborted a request/
let navigatingAway = false

// Load honeybadger dynamically so ad blockers don't break the entire app
const honeybadgerApiKey = document.querySelector('meta[name="honeybadger-api-key"]')?.content
if (honeybadgerApiKey) {
  // pagehide rather than beforeunload, which costs the page its bfcache entry
  window.addEventListener('pagehide', () => { navigatingAway = true })
  window.addEventListener('pageshow', () => { navigatingAway = false })
  import('@honeybadger-io/js')
    .then(({ default: Honeybadger }) => {
      Honeybadger.configure({
        apiKey: honeybadgerApiKey,
        environment: document.querySelector('meta[name="honeybadger-environment"]')?.content
      })
      Honeybadger.beforeNotify((notice) => {
        // Filter out browser extension errors
        if (notice.backtrace?.some((frame) => /^(chrome|moz|safari)-extension:\/\//.test(frame.file))) {
          return false
        }
        // Filter out ResizeObserver loop noise (benign browser warning)
        if (notice.message?.includes('ResizeObserver loop')) {
          return false
        }
        if (navigatingAway && NAVIGATION_FETCH_ERROR.test(notice.message)) {
          return false
        }
      })
    })
    .catch(() => {})
}

document.addEventListener('DOMContentLoaded', localizeTime)
document.addEventListener('turbo:render', localizeTime)
