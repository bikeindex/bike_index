import { Controller } from '@hotwired/stimulus'
import { DirectUpload } from '@rails/activestorage'

// Connects to data-controller='register--photo'
//
// One hidden file input serves both buttons: "Take Photo" adds the capture
// attribute (rear camera on mobile) before opening the picker, "Upload" removes it.
// Picking a photo uploads it straight to the storage bucket, so the form posts a
// signed blob id instead of megabytes of multipart body.
export default class extends Controller {
  static targets = ['input', 'filename', 'signedId']
  static values = { url: String, uploading: String, failed: String }

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

  takePhoto () {
    this.inputTarget.setAttribute('capture', 'environment')
    this.inputTarget.click()
  }

  upload () {
    this.inputTarget.removeAttribute('capture')
    this.inputTarget.click()
  }

  changed () {
    const file = this.inputTarget.files[0]
    if (!file) return

    this.xhr?.abort() // Picking again shouldn't leave the discarded photo uploading
    this.signedIdTarget.value = ''
    this.filenameTarget.textContent = `${file.name} — ${this.uploadingValue}`

    const upload = new DirectUpload(file, this.urlValue, this)
    this.upload = upload
    this.pending = new Promise((resolve) => upload.create((error, blob) => {
      resolve()
      if (this.upload !== upload) return // A newer pick owns the field now

      this.pending = null
      if (!error) this.signedIdTarget.value = blob.signed_id
      this.filenameTarget.textContent = error ? `${file.name} — ${this.failedValue}` : file.name
    }))
  }

  // DirectUpload delegate hook - the handle that makes a discarded upload cancellable
  directUploadWillStoreFileWithXHR (xhr) {
    this.xhr = xhr
  }

  // Submitting mid-upload would drop the photo, so hold the form until the blob lands.
  // The submit button is already disabled and spinning by then (UI::Button spinner).
  // A failed upload submits anyway - the rest of the registration matters more.
  async hold (event) {
    if (!this.pending) return

    event.preventDefault()
    await this.pending
    this.form.requestSubmit()
  }
}
