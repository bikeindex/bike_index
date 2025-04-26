import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='legacy-form-well--address-record-with-default--component'
export default class extends Controller {
  connect () {
    console.log('app/components/legacy_form_well/address_record_with_default/component_controller.js - connected to:')
    console.log(this.element)
  }
}
