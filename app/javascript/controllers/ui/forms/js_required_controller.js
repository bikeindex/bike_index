import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--js-required'
//
// A combobox with a no-JS fallback ships without `required`. Without JavaScript it's
// hidden and its input carries no name, and a browser refuses to submit a form holding
// a required control it can't focus ("An invalid form control with name='' is not
// focusable") - so the rider could fill the fallback in and still go nowhere. With
// JavaScript the combobox is the control they use, so mark it back.
export default class extends Controller {
  connect () {
    this.element.querySelector('[role="combobox"]')?.setAttribute('required', 'required')
  }
}
