import { Controller } from '@hotwired/stimulus'
import * as dropZone from 'utils/drop_zone'

// Connects to data-controller='ui--forms--file-upload-multi'
// Posts each picked or dropped file to the url, one request per file, and appends the markup
// the endpoint answers with to the list. There is no form around this - the endpoint stores
// the file on its own, so the page it sits on can be saved (or abandoned) independently.
export default class extends Controller {
  static targets = ['input', 'dropZone', 'list', 'status']
  static values = {
    url: String,
    params: Object,
    fileParam: { type: String, default: 'file' },
    uploading: String,
    failed: String
  }

  disconnect () {
    this.requests?.forEach((request) => request.abort())
  }

  dragOver (event) { dropZone.dragOver(event, this.dropZoneTarget) }

  endDrag (event) { dropZone.endDrag(event, this.dropZoneTarget) }

  highlightDropZone () { dropZone.highlight(this.dropZoneTarget) }

  unhighlightDropZone (event) { dropZone.unhighlight(event, this.dropZoneTarget) }

  drop (event) { dropZone.assignDroppedFiles(event, this.inputTarget) }

  // Each file gets its own request, so a slow one doesn't hold the others back and a
  // rejected one doesn't take them down with it.
  upload () {
    const files = [...this.inputTarget.files]
    // The picks are held by the requests now; clearing lets the same file be picked again
    this.inputTarget.value = ''
    files.forEach((file) => this.uploadFile(file))
  }

  uploadFile (file) {
    const row = this.statusRow(file)
    const body = new FormData()
    body.append(this.fileParamValue, file)
    Object.entries(this.paramsValue).forEach(([key, value]) => body.append(key, value))

    const request = new window.XMLHttpRequest()
    this.requests = [...(this.requests || []), request]
    request.open('POST', this.urlValue)
    request.responseType = 'json'
    request.setRequestHeader('X-CSRF-Token', document.querySelector('meta[name="csrf-token"]')?.content)
    request.upload.addEventListener('progress', (event) => this.showProgress(row, event))
    request.addEventListener('loadend', () => this.finish(request, row))
    request.send(body)
  }

  // The endpoint answers with the item's markup, or with the reason it wouldn't store the file
  finish (request, row) {
    this.requests = this.requests.filter((pending) => pending !== request)
    if (request.response?.html) {
      this.listTarget.insertAdjacentHTML('beforeend', request.response.html)
      return row.remove()
    }

    row.dataset.failed = 'true'
    row.lastElementChild.textContent = request.response?.error || this.failedValue
  }

  showProgress (row, event) {
    if (!event.lengthComputable) return

    const percent = Math.round((event.loaded / event.total) * 100)
    row.lastElementChild.textContent = `${this.uploadingValue} ${percent}%`
  }

  // The row stands in for the image until the endpoint answers with its markup
  statusRow (file) {
    const row = document.createElement('li')
    row.className = 'tw:flex tw:gap-2 tw:text-sm tw:text-gray-500 tw:data-[failed=true]:text-red-600 tw:dark:text-gray-400 tw:dark:data-[failed=true]:text-red-400'
    row.innerHTML = '<span class="tw:min-w-0 tw:truncate"></span><span class="tw:whitespace-nowrap"></span>'
    row.firstElementChild.textContent = file.name
    row.lastElementChild.textContent = this.uploadingValue
    this.statusTarget.appendChild(row)
    return row
  }
}
