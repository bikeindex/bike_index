import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--multiselect-required'
//
// hotwire_combobox leaves `required` on the text input, which a multiselect empties after
// every pick - so require it only while nothing is picked.
export default class extends Controller {
  connect () {
    this.#require(this.element.querySelector('[data-hw-combobox-target="hiddenField"]').value)
  }

  sync ({ detail: { value } }) {
    this.#require(value)
  }

  #require (value) {
    this.element.querySelector('[role="combobox"]').required = !value
  }
}
