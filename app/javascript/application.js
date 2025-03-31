import '@hotwired/turbo-rails'

// Import stimulus controllers
import { Application } from '@hotwired/stimulus'
// Lazy load all controllers
import { lazyLoadControllersFrom } from '@hotwired/stimulus-loading'

/* global Turbo */
// Disable Turbo by default, only enable on case-by-case
// You must include data-turbo="true" on the elements you want to enable turbo on
Turbo.session.drive = false
const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

lazyLoadControllersFrom('components', application)
