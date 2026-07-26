import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='form--file-upload'
// Shows the selected filename (or a count for multiple files) in the field, and
// reveals a drop zone while a file is dragged anywhere over the page.
export default class extends Controller {
  static targets = ['input', 'filename', 'dropZone']
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

  // Fires on every pointer move of the drag, so the reveal is guarded: collapse()
  // re-measures and cancels its own cleanup timer when called mid-animation.
  dragOver (event) {
    if (!draggingFile(event)) return
    event.preventDefault() // without this the browser opens the file instead
    if (this.dragging) return

    this.dragging = true
    collapse('show', this.dropZoneTarget)
  }

  // dragleave fires for every element crossed; relatedTarget is null only on leaving the window.
  dragLeave (event) {
    if (!event.relatedTarget) this.endDrag()
  }

  // Also runs for a drop on the zone, which prevented the event on its way past.
  endDrag (event) {
    event?.preventDefault()
    if (!this.dragging) return

    this.dragging = false
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
  return event.dataTransfer?.types?.includes('Files')
}
