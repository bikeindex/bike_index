// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails


// Import stimulus controllers
import { Application } from '@hotwired/stimulus';
const application = Application.start();
// Configure Stimulus development experience
application.debug = false;
window.Stimulus = application;
// Lazy load all controllers
import { lazyLoadControllersFrom } from '@hotwired/stimulus-loading';
lazyLoadControllersFrom('components', application);
