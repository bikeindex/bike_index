import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='pagination--component'
export default class extends Controller {
  connect () {
    console.log('app/components/pagination/component_controller.js - connected to:')
    console.log(this.element)
  }
}
