import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='header-tags--component'
export default class extends Controller {
  connect() {
    console.log('app/components/header_tags/component_controller.js - connected to:')
    console.log(this.element)
  }
}
