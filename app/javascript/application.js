import '@hotwired/turbo-rails'

// Import stimulus controllers
import { Application } from '@hotwired/stimulus'
// Lazy load all controllers
import { lazyLoadControllersFrom } from '@hotwired/stimulus-loading'

import TimeLocalizer from '@bikeindex/time-localizer'

// Escape option-value lookups so quoted search terms don't crash the combobox
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

// Load honeybadger dynamically so ad blockers don't break the entire app
const honeybadgerApiKey = document.querySelector('meta[name="honeybadger-api-key"]')?.content
if (honeybadgerApiKey) {
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
        // A fetch killed by navigating away, in the four phrasings browsers give it
        if (/Failed to fetch|Load failed|Fetch is aborted|aborted a request/.test(notice.message)) {
          return false
        }
      })
    })
    .catch(() => {})
}

document.addEventListener('DOMContentLoaded', localizeTime)
document.addEventListener('turbo:render', localizeTime)
