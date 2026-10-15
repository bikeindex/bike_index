import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='bikebook--read-more'
// Opens and closes a text shortened to its first words
export default class extends Controller {
  static targets = ['button']

  toggle () {
    this.buttonTarget.setAttribute('aria-expanded', this.element.toggleAttribute('data-expanded'))
  }
}
