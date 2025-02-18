import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='choose-membership--component'
export default class extends Controller {
  connect() {
    console.log('app/components/choose_membership/component_controller.js - connected to:')
    console.log(this.element)
  }
}
