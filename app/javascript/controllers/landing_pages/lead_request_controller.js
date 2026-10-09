import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='landing-pages--lead-request'
export default class extends Controller {
  static targets = ['radio']

  // A link to the contact form says which request it's for
  choose ({ params }) {
    this.radioTargets.forEach(radio => { radio.checked = radio.value === params.value })
  }
}
