import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--add-fields'
//
// Inserts a blank set of nested-attributes fields before the link. Rails renders them with a
// placeholder child index, which every added set has to swap for a unique one - two sets
// sharing an index submit as a single record. Replaces the vendored admin bundle's
// `.add_fields` jQuery handler.
export default class extends Controller {
  static values = { fields: String, childIndex: String }

  initialize () {
    this.added = 0
  }

  add (event) {
    event.preventDefault()
    // Date.now() alone collides when the link is clicked twice within a millisecond
    const index = `${Date.now()}${this.added++}`
    this.element.insertAdjacentHTML('beforebegin', this.fieldsValue.replaceAll(this.childIndexValue, index))
  }
}
