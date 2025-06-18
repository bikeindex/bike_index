import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='search--kind-option--component'
export default class extends Controller {
  connect () {
    console.log('app/components/search/kind_option/component_controller.js - connected to:')
    console.log(this.element)
  }
}
