import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='definition-list--row--component'
export default class extends Controller {
  connect () {
    console.log('app/components/definition_list/row/component_controller.js - connected to:')
    console.log(this.element)
  }
}
