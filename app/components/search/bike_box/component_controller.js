import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='search--bike-box--component'
export default class extends Controller {
  connect () {
    console.log('app/components/search/bike_box/component_controller.js - connected to:')
    console.log(this.element)
  }
}
