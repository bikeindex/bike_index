import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  // Catches an image that failed before the controller loaded
  connect () {
    const image = this.element.querySelector('img')
    if (image.complete && !image.naturalWidth) this.fail()
  }

  fail () {
    this.element.dataset.broken = ''
  }
}
