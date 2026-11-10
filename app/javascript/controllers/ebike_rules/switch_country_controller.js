import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ebike-rules--switch-country'
// A pick goes to its place's page. The gem also announces a blur that picked nothing
export default class extends Controller {
  choose ({ detail }) {
    if (detail?.value) this.element.requestSubmit()
  }
}
