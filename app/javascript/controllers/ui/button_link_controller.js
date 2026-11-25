import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--button-link'
export default class extends Controller {
  // An <a> answers Enter but not the spacebar, which scrolls instead. These render as
  // buttons and get used like them, so the key a button takes has to work too.
  activate (event) {
    if (event.key !== ' ') return

    event.preventDefault()
    this.element.click()
  }
}
