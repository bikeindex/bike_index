import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="auto-submit"
// Submits the form it's attached to as soon as it renders, so a page reached by an
// emailed GET link can act through a POST instead.
export default class extends Controller {
  connect () {
    this.element.requestSubmit()
  }
}
