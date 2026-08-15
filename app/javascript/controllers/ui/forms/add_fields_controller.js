import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--add-fields'
//
// Inserts a blank set of nested-attributes fields before the link. Every added set has to
// swap the server's __INDEX__ placeholder for a distinct one - two sets sharing an index
// submit as a single record.
export default class extends Controller {
  static values = { fields: String }

  initialize () {
    this.nextIndex = Date.now()
  }

  add (event) {
    event.preventDefault()
    this.element.insertAdjacentHTML('beforebegin', this.fieldsValue.replaceAll('__INDEX__', this.nextIndex++))
  }
}
