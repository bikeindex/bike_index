import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='search--form--component'
export default class extends Controller {
  connect () {
    // Remove search_no_js hidden field
    const noJsElement = this.element.querySelector('#search_no_js')
    if (noJsElement) noJsElement.remove()
  }
}
