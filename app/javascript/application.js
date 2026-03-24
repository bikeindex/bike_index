import '@hotwired/turbo-rails'
import '@honeybadger-io/js'

// Import stimulus controllers
import { Application } from '@hotwired/stimulus'
// Lazy load all controllers
import { lazyLoadControllersFrom } from '@hotwired/stimulus-loading'

import TimeLocalizer from '@bikeindex/time-localizer'

/* global Turbo Honeybadger */
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

const honeybadgerApiKey = document.querySelector('meta[name="honeybadger-api-key"]')?.content
if (honeybadgerApiKey) {
  Honeybadger.configure({
    apiKey: honeybadgerApiKey,
    environment: document.querySelector('meta[name="honeybadger-environment"]')?.content
  })
}

document.addEventListener('DOMContentLoaded', localizeTime)
document.addEventListener('turbo:render', localizeTime)
