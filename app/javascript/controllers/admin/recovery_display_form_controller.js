import { Controller } from "@hotwired/stimulus"
import { collapse } from 'utils/collapse_utils'
// import { collapse } from "../../utils/collapse-utils"

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
    if (this.bikeImageTextTarget.classList.contains("bike-image-added")) {
      collapse('show', this.photoUploadInputTarget)
      this.remoteImageUrlTarget.value = ""
      this.bikeImageTextTarget.classList.remove("bike-image-added")
    } else {
      collapse('hide', this.photoUploadInputTarget)
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
