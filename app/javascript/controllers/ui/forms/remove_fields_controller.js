import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ui--forms--remove-fields'
//
// Collapses a set of nested-attributes fields. The trigger is a label for the record's
// _destroy checkbox, so the click that hides these also marks them for destruction - nothing
// here needs to touch the checkbox. Replaces the vendored admin bundle's `.remove_fields`
// jQuery handler.
export default class extends Controller {
  remove () {
    collapse('hide', this.element)
  }
}
