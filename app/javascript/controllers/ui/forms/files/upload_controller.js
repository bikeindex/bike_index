import { Controller } from '@hotwired/stimulus'
import { DirectUpload } from '@rails/activestorage'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ui--forms--files--upload'
// Previews an image pick. With a url value, uploads the pick straight to storage and posts
// its signed blob id.
export default class extends Controller {
  static targets = ['input', 'preview', 'previewImage', 'signedId', 'status']
  // stall: how long without progress before the upload is treated as dead
  static values = {
    url: String,
    uploading: String,
    failed: String,
    stall: { type: Number, default: 30000 }
  }

  connect () {
    this.boundHold = this.hold.bind(this)
    // Captured on the document so it runs ahead of the form's own submit handlers -
    // strip-inputs resubmits the form itself, and only bows out to a prevented submit
    document.addEventListener('submit', this.boundHold, true)
    // The field posts its own bytes until this runs, which is what makes the form work
    // without JS - once we're uploading, the signed id is what the form carries instead.
    if (this.urlValue) this.inputTarget.removeAttribute('name')
  }

  disconnect () {
    document.removeEventListener('submit', this.boundHold, true)
    clearTimeout(this.stallTimer)
    this.releaseObjectUrl()
  }

  get form () {
    return this.element.closest('form')
  }

  picked ({ detail: { files } }) {
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

  // Only reached with a direct_upload_url, where the form carries the blob's signed id
  // rather than the bytes.
  upload (file) {
    this.abortUpload() // Picking again shouldn't leave the discarded file uploading
    this.signedIdTarget.value = ''
    this.status(this.uploadingValue)

    const upload = new DirectUpload(file, this.urlValue, this)
    this.currentUpload = upload
    this.pending = new Promise((resolve) => { this.settle = resolve })
    upload.create((error, blob) => {
      if (this.currentUpload !== upload) return // A newer pick owns the field now

      if (!error) this.signedIdTarget.value = blob.signed_id
      this.status(error && this.failedValue, !!error)
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
      this.status(this.failedValue, true)
      this.abortUpload()
    }, this.stallValue)
  }

  status (text, failed = false) {
    this.statusTarget.textContent = text || ''
    this.statusTarget.dataset.failed = failed
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

    this.status(`${this.uploadingValue} ${percent(event)}%`)
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

function percent (event) {
  return Math.round((event.loaded / event.total) * 100)
}
