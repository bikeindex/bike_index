import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='legacy-form-wrap--address-record--component'
export default class extends Controller {
  connect () {
    console.log('app/components/legacy_form_wrap/address_record/component_controller.js - connected to:')
    console.log(this.element)
  }
}
