// Import jquery at the top so that we can use select2
import "jquery"
window.jQuery = jQuery
// window.$ = jQuery

// Import stimulus controllers
import { Application } from '@hotwired/stimulus'
// Lazy load all controllers
import { lazyLoadControllersFrom } from '@hotwired/stimulus-loading'
const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

lazyLoadControllersFrom('components', application)
