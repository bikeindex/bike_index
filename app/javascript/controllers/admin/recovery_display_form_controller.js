import { Controller } from "@hotwired/stimulus"

// Connects to data-controller='admin--update-cached-sortable-links
export default class extends Controller {
  static targets = [
    "characterCounter",
    "characterTotal",
    "photoUploadInput",
    "remoteImageUrl",
    "bikeImageText",
    "useImageButton"
  ]

  static values = {
    toggleImageInitially: Boolean,
    maxCharacterCount: Number
  }

  connect() {
    console.log("HERHERHER")
    this.setCharacterCount()

    if (this.toggleImageInitiallyValue) {
      this.toggleBikeImageForDisplay()
    }
  }

  toggleImage(event) {
    event.preventDefault()
    this.toggleBikeImageForDisplay()
  }

  toggleBikeImageForDisplay() {
    const collapse = new bootstrap.Collapse(this.photoUploadInputTarget, {
      toggle: false
    })

    if (this.bikeImageTextTarget.classList.contains("bike-image-added")) {
      collapse.show()
      this.remoteImageUrlTarget.value = ""
      this.bikeImageTextTarget.classList.remove("bike-image-added")
    } else {
      collapse.hide()
      this.remoteImageUrlTarget.value = this.useImageButtonTarget.dataset.url
      this.bikeImageTextTarget.classList.add("bike-image-added")
    }
  }

  updateCharacterCount() {
    this.setCharacterCount()
  }

  setCharacterCount() {
    const length = this.characterCounterTarget.value.length
    this.characterTotalTarget.textContent = `${length}/${this.maxCharacterCountValue}`
  }
}
