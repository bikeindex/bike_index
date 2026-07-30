import { Controller } from '@hotwired/stimulus'
import { DirectUpload } from '@rails/activestorage'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ui--forms--file-upload'
// Shows the selected filename (or a count for multiple files) in the field, previews an
// image pick, and frames the controls as a drop target while a file is dragged over the page.
// With a url value, uploads the pick straight to storage and posts its signed blob id.
export default class extends Controller {
  static targets = ['input', 'filename', 'dropZone', 'preview', 'previewImage', 'signedId']
  static values = { placeholder: String, url: String, uploading: String, failed: String }

  connect () {
    this.boundHold = this.hold.bind(this)
    this.form?.addEventListener('submit', this.boundHold)
  }

  disconnect () {
    this.form?.removeEventListener('submit', this.boundHold)
    this.releaseObjectUrl()
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
    this.showPreview(files[0])
    if (this.urlValue && files[0]) this.upload(files[0])
  }

  // Reads the file the browser already holds, so the preview lands on the pick rather than
  // on a round trip -- and shows the original rather than a processed copy of it.
  showPreview (file) {
    this.releaseObjectUrl()
    // An empty pick leaves whatever is attached on screen, since that's still what will submit
    if (!file) return

    const preview = this.previewTarget
    if (!file.type.startsWith('image/')) return collapse('hide', preview)

    const image = this.previewImageTarget
    this.objectUrl = URL.createObjectURL(file)
    // Assigned rather than added, so a re-pick replaces these instead of stacking them.
    // collapse animates to the natural height, which isn't known until the image decodes --
    // and a file that won't decode shouldn't leave the previous preview on screen.
    image.onload = () => collapse('show', preview)
    image.onerror = () => collapse('hide', preview)
    image.src = this.objectUrl
    preview.href = this.objectUrl
  }

  // Each object url pins the file in memory until it's revoked
  releaseObjectUrl () {
    if (!this.objectUrl) return

    URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
  }

  // Only reached with a direct_upload_url, where the field is nameless and the form carries
  // the blob's signed id rather than the bytes.
  upload (file) {
    this.xhr?.abort() // Picking again shouldn't leave the discarded file uploading
    this.signedIdTarget.value = ''
    this.status(file, this.uploadingValue)

    const upload = new DirectUpload(file, this.urlValue, this)
    this.currentUpload = upload
    this.pending = new Promise((resolve) => upload.create((error, blob) => {
      resolve()
      if (this.currentUpload !== upload) return // A newer pick owns the field now

      this.pending = null
      if (!error) this.signedIdTarget.value = blob.signed_id
      this.status(file, error && this.failedValue)
    }))
  }

  status (file, suffix) {
    this.filenameTarget.textContent = suffix ? `${file.name} — ${suffix}` : file.name
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
