import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='bikebook--copy-button'
export default class extends Controller {
  static values = { text: String }

  async copy () {
    await navigator.clipboard.writeText(this.textValue)
    this.element.dataset.copied = ''
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => delete this.element.dataset.copied, 1500)
  }
}
