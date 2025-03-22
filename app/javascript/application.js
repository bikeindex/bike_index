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

// Add the following two lines:
import HwComboboxController from "controllers/hw_combobox_controller"
application.register("hw-combobox", HwComboboxController)
