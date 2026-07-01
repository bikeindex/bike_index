import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='form--file-upload'
// Shows the selected filename (or a count for multiple files) in the field.
export default class extends Controller {
  static targets = ['input', 'filename']
  static values = { placeholder: String }

  display () {
    const { files } = this.inputTarget
    this.filenameTarget.textContent =
      files.length === 0
        ? this.placeholderValue
        : files.length === 1 ? files[0].name : `${files.length} files`
  }
}
