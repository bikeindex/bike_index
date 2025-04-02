import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='search--form--component'
export default class extends Controller {
  static targets = ['form']
  static values = { spinnerId: { type: String, default: "hiddenLoadingSpinner" } }

  get frameElement() {
    const turboFrameId = this.formTarget.getAttribute("data-turbo-frame")

    return(document.getElementById(turboFrameId))
  }

  connect () {
    // Remove search_no_js hidden field
    const noJsElement = this.element.querySelector('#search_no_js')
    if (noJsElement) noJsElement.remove()

    // if the frame was loaded without results, submit the form (so we )
    if (this.frameElement?.querySelector("#loadedWithoutResults")) {
      this.formTarget.requestSubmit()
    }
  }

  initialize() {
    // every time the form submits, show the loading spinner
    this.formTarget.addEventListener("turbo:submit-start", this.showLoadingSpinner.bind(this))
  }

  showLoadingSpinner() {
    if (!this.frameElement) return

    const spinnerWrapper = document.getElementById(this.spinnerIdValue)
    // IDK if this should clone instead of just use innerHTML - this seems much simpler
    this.frameElement.innerHTML = spinnerWrapper.innerHTML
  }
}
