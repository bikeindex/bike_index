import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='messages--threads--component'
export default class extends Controller {
  connect () {
    console.log('app/components/messages/threads/component_controller.js - connected to:')
    console.log(this.element)
  }
}
