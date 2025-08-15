import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='messages--thread-show--component'
export default class extends Controller {
  connect () {
    console.log('app/components/messages/thread_show/component_controller.js - connected to:')
    console.log(this.element)
  }
}
