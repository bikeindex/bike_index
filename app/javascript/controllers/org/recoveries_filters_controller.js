import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--recoveries-filters'
// Each filter is a search of its own. They sit outside the form, joined to it by its id,
// so the change reaches here rather than the form
export default class extends Controller {
  submit (event) {
    event.target.form?.requestSubmit()
  }
}
