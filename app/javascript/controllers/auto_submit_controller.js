import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='auto-submit'
// Submits the form on load, so a page that only exists to post what its URL already
// carries needs a click only when JavaScript doesn't run.
export default class extends Controller {
  connect () {
    this.element.requestSubmit()
  }
}
