import '@hotwired/turbo-rails';

/*global Turbo*/
// Disable Turbo by default, only enable on case-by-case
// You must include data-turbo="true" on the elements you want to enable turbo on
Turbo.session.drive = false;

// Import stimulus controllers
import { Application } from '@hotwired/stimulus'
// Lazy load all controllers
import { lazyLoadControllersFrom } from '@hotwired/stimulus-loading'
const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

lazyLoadControllersFrom('components', application)
