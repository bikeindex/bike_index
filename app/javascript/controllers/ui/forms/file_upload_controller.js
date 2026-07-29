import { Controller } from '@hotwired/stimulus'
import { DirectUpload } from '@rails/activestorage'

// Connects to data-controller='ui--forms--file-upload'
// Shows the selected filename (or a count for multiple files) in the field, and
// frames the controls as a drop target while a file is dragged over the page.
export default class extends Controller {
  static targets = ['input', 'filename', 'dropZone', 'signedId']
  static values = { placeholder: String, url: String, uploading: String, failed: String }

  connect () {
    this.boundHold = this.hold.bind(this)
    this.form?.addEventListener('submit', this.boundHold)
  }

  disconnect () {
    this.form?.removeEventListener('submit', this.boundHold)
  }

  get form () {
    return this.element.closest('form')
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

  dragOver (event) {
    if (!draggingFile(event)) return
    event.preventDefault() // without this the browser opens the file instead

    this.dropZoneTarget.dataset.dragging = 'true'
  }

  // Bound to both dragleave and drop. dragleave fires for every element crossed, but
  // relatedTarget is null only on leaving the window -- and on a drop, which ends it too.
  endDrag (event) {
    if (event.relatedTarget) return
    event.preventDefault()

    delete this.dropZoneTarget.dataset.dragging
    this.unhighlightDropZone()
  }

  highlightDropZone () {
    this.dropZoneTarget.dataset.over = 'true'
  }

  // The frame wraps the controls, so dragging onto one of them leaves the frame
  // in the event's terms -- only a relatedTarget outside it is a real exit.
  unhighlightDropZone (event) {
    if (event?.relatedTarget && this.dropZoneTarget.contains(event.relatedTarget)) return

    delete this.dropZoneTarget.dataset.over
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
    if (this.urlValue) this.upload(files[0])
  }

  // Only when the field is nameless (direct_upload) - the form then carries the blob's
  // signed id rather than the bytes.
  upload (file) {
    if (!file) return

    this.xhr?.abort() // Picking again shouldn't leave the discarded file uploading
    this.signedIdTarget.value = ''
    this.filenameTarget.textContent = `${file.name} — ${this.uploadingValue}`

    const upload = new DirectUpload(file, this.urlValue, this)
    this.currentUpload = upload
    this.pending = new Promise((resolve) => upload.create((error, blob) => {
      resolve()
      if (this.currentUpload !== upload) return // A newer pick owns the field now

      this.pending = null
      if (!error) this.signedIdTarget.value = blob.signed_id
      this.filenameTarget.textContent = error ? `${file.name} — ${this.failedValue}` : file.name
    }))
  }

  // DirectUpload delegate hook - the handle that makes a discarded upload cancellable
  directUploadWillStoreFileWithXHR (xhr) {
    this.xhr = xhr
  }

  // Submitting mid-upload would drop the file, so hold the form until the blob lands.
  // A failed upload submits anyway - the rest of the form matters more.
  async hold (event) {
    if (!this.pending) return

    event.preventDefault()
    await this.pending
    this.form.requestSubmit()
  }
}

// Dragged text and page elements fire these events too; only files matter here.
function draggingFile (event) {
  return event.dataTransfer?.types?.includes('Files')
}
