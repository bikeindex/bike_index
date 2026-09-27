import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--column-checkboxes'
export default class extends Controller {
  selectAll () {
    this.check(() => true)
  }

  selectNone () {
    this.check(() => false)
  }

  selectDefault () {
    this.check(checkbox => checkbox.dataset.default === 'true')
  }

  // A disabled checkbox is an always-shown column, and stays checked. The one change event
  // is what a caller watching the element hears, as it does a single checkbox's
  check (checkedFor) {
    this.element.querySelectorAll('input[type=checkbox]:not(:disabled)').forEach(checkbox => {
      checkbox.checked = checkedFor(checkbox)
    })
    this.element.dispatchEvent(new Event('change', { bubbles: true }))
  }
}
