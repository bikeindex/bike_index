import '@hotwired/turbo-rails'

// Import stimulus controllers
import { Application } from '@hotwired/stimulus'
// Lazy load all controllers
import { lazyLoadControllersFrom } from '@hotwired/stimulus-loading'

import TimeLocalizer from '@bikeindex/time-localizer'

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

// A network failure, a module fetch included, reads the same whoever made it - so it reports
// only with our code on the stack, and not while the page is going away
const NETWORK_ERROR = /Failed to fetch|Load failed|Fetch is aborted|aborted a request|Importing a module script failed|error loading dynamically imported module/
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
        environment: document.querySelector('meta[name="honeybadger-environment"]')?.content,
        // One looping tab sent 59k notices in a day
        maxErrors: 20
      })
      // Turbo keeps one JS context across visits, so the cap would otherwise span the session
      document.addEventListener('turbo:load', () => Honeybadger.resetMaxErrors())
      Honeybadger.beforeNotify((notice) => {
        // Filter out browser extension errors
        if (notice.backtrace?.some((frame) => /^(chrome|moz|safari)-extension:\/\//.test(frame.file))) {
          return false
        }
        // Filter out ResizeObserver loop noise (benign browser warning)
        if (notice.message?.includes('ResizeObserver loop')) {
          return false
        }
        // Honeybadger's bundle wraps fetch and timers, so its frames turn up under anyone's error
        const fromOurCode = notice.backtrace?.some((frame) => /\/assets\/(?!@honeybadger-io)/.test(frame.file))
        if (NETWORK_ERROR.test(notice.message) && (navigatingAway || !fromOurCode)) {
          return false
        }
        // Injected scripts whose frames dodge the extension filter: Google's iOS apps (GSA, CriOS)
        // recurse, filed by WebKit under the page's URL; Firefox extensions touch a torn-down
        // window, filed as unknown:0
        if (/Maximum call stack size exceeded|can't access dead object/.test(notice.message) && !fromOurCode) {
          return false
        }
      })
    })
    .catch(() => {})
}

document.addEventListener('DOMContentLoaded', localizeTime)
document.addEventListener('turbo:render', localizeTime)
