import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--files--upload-multiple'
// Posts each pick to the url on its own, and the markup the endpoint answers with joins the list.
export default class extends Controller {
  static targets = ['list', 'status']
  static values = { url: String, params: Object, fileParam: String, uploading: String, failed: String }

  connect () {
    this.requests = new Set()
  }

  disconnect () {
    this.requests.forEach((request) => request.abort())
  }

  // One request per file, so a slow one doesn't hold the rest back and a rejected one
  // doesn't take them down with it.
  picked ({ detail: { files, input } }) {
    // The requests hold the files now; clearing lets the same one be picked again
    input.value = ''
    files.forEach((file) => this.post(file))
  }

  post (file) {
    const row = this.statusRow(file)
    const body = new FormData()
    body.append(this.fileParamValue, file)
    Object.entries(this.paramsValue).forEach(([key, value]) => body.append(key, value))

    const request = new window.XMLHttpRequest()
    this.requests.add(request)
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
    this.requests.delete(request)
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
}

function percent (event) {
  return Math.round((event.loaded / event.total) * 100)
}
