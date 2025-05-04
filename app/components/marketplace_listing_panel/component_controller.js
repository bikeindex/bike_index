import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='marketplace-listing-panel--component'
export default class extends Controller {
  connect () {
    console.log('app/components/marketplace_listing_panel/component_controller.js - connected to:')
    console.log(this.element)
  }
}
