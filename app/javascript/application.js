// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

// Import stimulus controllers
import { Application } from '@hotwired/stimulus'
// Lazy load all controllers
import { lazyLoadControllersFrom } from '@hotwired/stimulus-loading'
const application = Application.start()
// Configure Stimulus development experience
application.debug = false
window.Stimulus = application
lazyLoadControllersFrom('components', application)
