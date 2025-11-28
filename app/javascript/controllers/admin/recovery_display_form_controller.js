import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'
// import { collapse } from "../../utils/collapse-utils"

// Connects to data-controller='admin--update-cached-sortable-links
export default class extends Controller {
  static targets = [
    "characterCounter",
    "characterTotal",
    "photoUploadInput",
    "remotePhotoUrl",
    "bikeImageText",
    "useImageButton",
    "usingBikeImage",
    "notUsingBikeImage"
  ]

  static values = {
    toggleImage: Boolean,
    maxCharacterCount: Number,
    remotePhotoUrl: String
  }

  connect () {
    console.log(this.remotePhotoUrlValue)
    this.setCharacterCount()

    if (this.toggleImageValue) {
      this.toggleBikeImageForDisplay()
    }
  }

  toggleImage (event) {
    event.preventDefault()
    this.toggleBikeImageForDisplay()
  }

  toggleBikeImageForDisplay() {
    if (this.toggleImageValue) {
      // Use bike image
      this.usingBikeImageTargets.forEach(el => collapse('show', el))
      this.notUsingBikeImageTargets.forEach(el => collapse('hide', el))
      this.remotePhotoUrlTarget.value = this.remotePhotoUrlValue
      this.toggleImageValue = false
    } else {
      // Switch back to upload form
      this.notUsingBikeImageTargets.forEach(el => collapse('show', el))
      this.usingBikeImageTargets.forEach(el => collapse('hide', el))
      this.remotePhotoUrlTarget.value = ""
      this.toggleImageValue = true
    }
  }

  updateCharacterCount () {
    this.setCharacterCount()
  }

  setCharacterCount () {
    const length = this.characterCounterTarget.value.length
    this.characterTotalTarget.textContent = `${length}/${this.maxCharacterCountValue}`
  }
}
