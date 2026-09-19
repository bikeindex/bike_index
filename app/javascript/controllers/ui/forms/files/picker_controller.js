import { Controller } from '@hotwired/stimulus'
import { DirectUpload } from '@rails/activestorage'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ui--forms--files--picker'
// Shows the selected filename (or a count for multiple files) in the field, previews an
// image pick, and frames the controls as a drop target while a file is dragged over the page.
// With a url value, uploads the pick straight to storage and posts its signed blob id.
// With a list (UI::Forms::Files::UploadMultiple), the url is an endpoint instead: each pick is
// posted to it on its own, and the markup it answers with joins the list.
export default class extends Controller {
  static targets = ['input', 'filename', 'dropZone', 'preview', 'previewImage', 'signedId', 'list', 'status']
  // stall: how long without progress before the upload is treated as dead
  static values = {
    placeholder: String,
    url: String,
    uploading: String,
    failed: String,
    stall: { type: Number, default: 30000 },
    params: Object,
    fileParam: String
  }

  connect () {
    this.boundHold = this.hold.bind(this)
    // Captured on the document so it runs ahead of the form's own submit handlers -
    // strip-inputs resubmits the form itself, and only bows out to a prevented submit
    document.addEventListener('submit', this.boundHold, true)
    // The field posts its own bytes until this runs, which is what makes the form work
    // without JS - once we're uploading, the signed id is what the form carries instead.
    if (this.urlValue) this.inputTarget.removeAttribute('name')
    this.listRequests = new Set()
  }

  disconnect () {
    document.removeEventListener('submit', this.boundHold, true)
    clearTimeout(this.stallTimer)
    this.releaseObjectUrl()
    this.listRequests.forEach((request) => request.abort())
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
    if (this.hasListTarget) return this.postEach()

    this.showPreview(files[0])
    if (this.urlValue && files[0]) this.upload(files[0])
  }

  // One request per file, so a slow one doesn't hold the rest back and a rejected one
  // doesn't take them down with it.
  postEach () {
    const files = [...this.inputTarget.files]
    // The requests hold the files now; clearing lets the same one be picked again
    this.inputTarget.value = ''
    files.forEach((file) => this.post(file))
  }

  post (file) {
    const row = this.statusRow(file)
    const body = new FormData()
    body.append(this.fileParamValue, file)
    Object.entries(this.paramsValue).forEach(([key, value]) => body.append(key, value))

    const request = new window.XMLHttpRequest()
    this.listRequests.add(request)
    request.open('POST', this.urlValue)
    request.responseType = 'json'
    request.setRequestHeader('X-CSRF-Token', document.querySelector('meta[name="csrf-token"]')?.content)
    request.upload.addEventListener('progress', (event) => {
      if (event.lengthComputable) row.lastElementChild.textContent = `${this.uploadingValue} ${percent(event)}%`
    })
    request.addEventListener('loadend', () => this.posted(request, row))
    request.send(body)
  }

  posted (request, row) {
    this.listRequests.delete(request)
    if (request.response?.html) {
      this.listTarget.insertAdjacentHTML('beforeend', request.response.html)
      return row.remove()
    }

    row.dataset.failed = 'true'
    row.lastElementChild.textContent = request.response?.error || this.failedValue
  }

  statusRow (file) {
    const row = document.createElement('li')
    row.className = 'tw:flex tw:gap-2 tw:text-sm tw:text-gray-500 tw:data-[failed=true]:text-red-600 tw:dark:text-gray-400 tw:dark:data-[failed=true]:text-red-400'
    row.innerHTML = '<span class="tw:min-w-0 tw:truncate"></span><span class="tw:whitespace-nowrap"></span>'
    row.firstElementChild.textContent = file.name
    row.lastElementChild.textContent = this.uploadingValue
    this.statusTarget.appendChild(row)
    return row
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

  // Only reached with a direct_upload_url, where the form carries the blob's signed id
  // rather than the bytes.
  upload (file) {
    this.abortUpload() // Picking again shouldn't leave the discarded file uploading
    this.signedIdTarget.value = ''
    this.uploadingFile = file
    this.status(file, this.uploadingValue)

    const upload = new DirectUpload(file, this.urlValue, this)
    this.currentUpload = upload
    this.pending = new Promise((resolve) => { this.settle = resolve })
    upload.create((error, blob) => {
      if (this.currentUpload !== upload) return // A newer pick owns the field now

      if (!error) this.signedIdTarget.value = blob.signed_id
      this.status(file, error && this.failedValue)
      this.finish()
    })
    this.watchForStall()
  }

  // Every ending runs through here, because a submit waiting on `pending` only moves when
  // it settles - including the endings DirectUpload never reports.
  finish () {
    clearTimeout(this.stallTimer)
    this.currentUpload = null
    this.pending = null
    this.settle?.()
    this.settle = null
  }

  // DirectUpload listens for load and error, not abort, so an aborted upload never reaches
  // its callback - without settling it here a held submit would wait on it forever.
  abortUpload () {
    if (!this.currentUpload) return

    this.xhr?.abort()
    this.finish()
  }

  // A connection that stops moving never errors, so nothing else would end the upload -
  // the form would sit disabled behind a spinner until the page was reloaded.
  watchForStall () {
    clearTimeout(this.stallTimer)
    this.stallTimer = setTimeout(() => {
      this.signedIdTarget.value = ''
      this.status(this.uploadingFile, this.failedValue)
      this.abortUpload()
    }, this.stallValue)
  }

  status (file, suffix) {
    this.filenameTarget.textContent = suffix ? `${file.name} — ${suffix}` : file.name
  }

  // DirectUpload delegate hook - the handle that makes a discarded upload cancellable
  directUploadWillStoreFileWithXHR (xhr) {
    this.xhr = xhr
    xhr.upload.addEventListener('progress', (event) => this.showProgress(event))
  }

  // Bytes moving is also what proves the connection is alive, so this restarts the stall watch
  showProgress (event) {
    this.watchForStall()
    if (!event.lengthComputable) return

    this.status(this.uploadingFile, `${this.uploadingValue} ${percent(event)}%`)
  }

  // Submitting mid-upload would drop the file, so hold the form until the blob lands.
  // A failed upload submits anyway - the rest of the form matters more.
  async hold (event) {
    if (!this.pending || event.target !== this.form) return

    event.preventDefault()
    await this.pending
    this.form.requestSubmit()
  }
}

// Dragged text and page elements fire these events too; only files matter here.
function draggingFile (event) {
  return event.dataTransfer?.types?.includes('Files')
}

function percent (event) {
  return Math.round((event.loaded / event.total) * 100)
}
