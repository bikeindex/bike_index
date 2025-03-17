import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='bike-search-form--component'
export default class extends Controller {
  connect() {
    console.log('app/components/bike_search_form/component_controller.js - connected to:')
    console.log(this.element)
  }
}
