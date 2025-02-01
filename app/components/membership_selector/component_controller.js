import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='membership-selector--component'
export default class extends Controller {
  connect() {
    console.log('app/components/membership_selector/component_controller.js - connected to:')
    console.log(this.element)
  }
}
