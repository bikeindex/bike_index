import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='admin--recovery-display-form'
export default class extends Controller {
  static targets = [
    'characterCounter',
    'characterTotal',
    'photoUploadInput',
    'remotePhotoUrl',
    'bikeImageText',
    'useImageButton',
    'usingBikeImage',
    'notUsingBikeImage'
  ]

  static values = {
    toggleImage: Boolean,
    maxCharacterCount: Number,
    remotePhotoUrl: String
  }

  connect () {
    this.setCharacterCount()

    if (this.toggleImageValue) {
      this.toggleBikeImageForDisplay()
    }
  }

  toggleImage (event) {
    event.preventDefault()
    this.toggleBikeImageForDisplay()
  }

  toggleBikeImageForDisplay () {
    if (this.toggleImageValue) {
      // Use bike image
      collapse('show', this.usingBikeImageTargets)
      collapse('hide', this.notUsingBikeImageTargets)
      this.remotePhotoUrlTarget.value = this.remotePhotoUrlValue
      this.toggleImageValue = false
    } else {
      // Switch back to upload form
      collapse('show', this.notUsingBikeImageTargets)
      collapse('hide', this.usingBikeImageTargets)
      this.remotePhotoUrlTarget.value = ''
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
