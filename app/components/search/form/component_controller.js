import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='search--form--component'
export default class extends Controller {
  connect () {
    console.log('app/components/search/form/component_controller.js - connected to:')
    console.log(this.element)
  }
}
