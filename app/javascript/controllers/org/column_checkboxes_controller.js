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

  // A disabled checkbox is an always-shown column. The change tells a caller watching the
  // element, as a single checkbox's does
  check (checkedFor) {
    this.element.querySelectorAll('input[type=checkbox]:not(:disabled)').forEach(checkbox => {
      checkbox.checked = checkedFor(checkbox)
    })
    this.element.dispatchEvent(new Event('change', { bubbles: true }))
  }
}
