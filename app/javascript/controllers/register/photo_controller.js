import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='register--photo'
//
// One hidden file input serves both buttons: "Take Photo" adds the capture
// attribute (rear camera on mobile) before opening the picker, "Upload" removes it.
export default class extends Controller {
  static targets = ['input', 'filename']

  takePhoto () {
    this.inputTarget.setAttribute('capture', 'environment')
    this.inputTarget.click()
  }

  upload () {
    this.inputTarget.removeAttribute('capture')
    this.inputTarget.click()
  }

  changed () {
    this.filenameTarget.textContent = this.inputTarget.files[0]?.name || ''
  }
}
