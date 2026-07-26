import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='form--file-upload'
// Shows the selected filename (or a count for multiple files) in the field.
export default class extends Controller {
  static targets = ['input', 'filename']
  static values = { placeholder: String }

  // Both buttons open the one input; `capture` is what sends it to the camera.
  takePicture () {
    this.inputTarget.setAttribute('capture', 'environment')
    this.inputTarget.click()
  }

  // Runs before the label's own activation forwards the click to the input.
  chooseFile () {
    this.inputTarget.removeAttribute('capture')
  }

  display () {
    const { files } = this.inputTarget
    this.filenameTarget.textContent =
      files.length === 0
        ? this.placeholderValue
        : files.length === 1 ? files[0].name : `${files.length} files`
  }
}
