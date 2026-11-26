import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--recoveries-filters'
// The filters sit outside their form, joined by its id, so a change never bubbles to it
export default class extends Controller {
  submit (event) {
    event.target.form?.requestSubmit()
  }
}
