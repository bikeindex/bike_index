import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='form--file-upload'
// Shows the selected filename (or a count for multiple files) in the field, and
// reveals a drop zone while a file is dragged anywhere over the page.
export default class extends Controller {
  static targets = ['input', 'filename', 'dropZone']
  static values = { placeholder: String }

  connect () {
    this.dragOver = this.dragOver.bind(this)
    this.dragEnd = this.dragEnd.bind(this)
    document.addEventListener('dragover', this.dragOver)
    document.addEventListener('dragleave', this.dragEnd)
    document.addEventListener('drop', this.dragEnd)
  }

  disconnect () {
    document.removeEventListener('dragover', this.dragOver)
    document.removeEventListener('dragleave', this.dragEnd)
    document.removeEventListener('drop', this.dragEnd)
  }

  // Both buttons open the one input; `capture` is what sends it to the camera.
  takePicture () {
    this.inputTarget.setAttribute('capture', 'environment')
    this.inputTarget.click()
  }

  // Runs before the label's own activation forwards the click to the input.
  chooseFile () {
    this.inputTarget.removeAttribute('capture')
  }

  // Repeats while the file is over the page. Preventing dragover (and drop
  // below) is what stops the browser from navigating to the dropped file.
  dragOver (event) {
    if (!draggingFile(event)) return
    event.preventDefault()
    collapse('show', this.dropZoneTarget)
  }

  dragEnd (event) {
    if (event.type === 'drop') event.preventDefault()
    // dragleave fires for every element crossed; relatedTarget is null only on leaving the window
    else if (event.relatedTarget) return

    collapse('hide', this.dropZoneTarget)
    this.unhighlightDropZone()
  }

  // is-active styles the zone under the cursor (see application.css).
  highlightDropZone () {
    this.dropZoneTarget.dataset.active = 'true'
  }

  unhighlightDropZone () {
    delete this.dropZoneTarget.dataset.active
  }

  drop (event) {
    event.preventDefault()
    const dropped = [...event.dataTransfer.files]
    if (dropped.length === 0) return

    // Assigning a FileList is the only way to fill a file input; `multiple`
    // decides how much of the drop it can hold.
    const transfer = new window.DataTransfer()
    ;(this.inputTarget.multiple ? dropped : dropped.slice(0, 1)).forEach((file) => transfer.items.add(file))
    this.inputTarget.files = transfer.files
    // Assigning files fires nothing. Picking a file natively fires both, and both
    // have listeners: `input` drives display(), `change` is what callers bind to.
    this.inputTarget.dispatchEvent(new Event('input', { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
  }

  display () {
    const { files } = this.inputTarget
    this.filenameTarget.textContent =
      files.length === 0
        ? this.placeholderValue
        : files.length === 1 ? files[0].name : `${files.length} files`
  }
}

// Dragged text and page elements fire these events too; only files matter here.
function draggingFile (event) {
  return [...(event.dataTransfer?.types || [])].includes('Files')
}
