import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='search--vehicle-thumbnail--component'
export default class extends Controller {
  connect () {
    console.log('app/components/search/vehicle_thumbnail/component_controller.js - connected to:')
    console.log(this.element)
  }
}
