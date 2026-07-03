import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='bike-photos'
// Swaps the large photo in [data-bike-photos-target=main] to match the clicked
// [data-bike-photos-target=thumbnail], toggling data-bike-photos-active-class
// onto whichever thumbnail is currently selected.
export default class extends Controller {
  static targets = ['main', 'thumbnail']
  static classes = ['active']

  select (event) {
    const thumbnail = event.currentTarget
    this.mainTarget.src = thumbnail.dataset.largeUrl
    this.mainTarget.alt = thumbnail.dataset.photoAlt
    this.thumbnailTargets.forEach((el) => el.classList.toggle(this.activeClass, el === thumbnail))
  }
}
