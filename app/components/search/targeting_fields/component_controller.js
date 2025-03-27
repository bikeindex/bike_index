import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='search--targeting-fields--component'
export default class extends Controller {
  connect () {
    console.log('app/components/search/targeting_fields/component_controller.js - connected to:')
    console.log(this.element)
  }
}
