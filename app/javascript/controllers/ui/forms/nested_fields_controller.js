import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ui--forms--nested-fields'
//
// Follows the contract @stimulus-components/rails-nested-form established: a [target=template]
// holding one blank set, a [target=target] marking where added ones go, and a wrapper per set.
//
// Every added set swaps the server's __INDEX__ placeholder for a distinct one - two sets
// sharing an index submit as a single record.
export default class extends Controller {
  static targets = ['target', 'template']
  // UI::Forms::NestedFields::Component owns the class and passes it down
  static values = { wrapperSelector: String }

  initialize () {
    this.nextIndex = Date.now()
  }

  add () {
    const fields = this.templateTarget.innerHTML.replaceAll('__INDEX__', this.nextIndex++)
    this.targetTarget.insertAdjacentHTML('beforebegin', fields)
    this.dispatch('add')
  }

  remove (event) {
    event.preventDefault()
    const wrapper = event.target.closest(this.wrapperSelectorValue)

    // A record that was never saved has nothing to destroy, and leaving it hidden in the form
    // would block submission on any required field it contains
    if (wrapper.dataset.newRecord === 'true') {
      wrapper.remove()
    } else {
      collapse('hide', wrapper)
      wrapper.querySelector("input[name*='_destroy']").value = '1'
    }

    this.dispatch('remove')
  }
}
