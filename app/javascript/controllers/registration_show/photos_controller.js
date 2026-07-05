import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='registration-show--photos'
// Swaps the large photo in [data-registration-show--photos-target=main] to match
// the clicked [data-registration-show--photos-target=thumbnail], toggling
// data-registration-show--photos-active-class onto the selected thumbnail.
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
