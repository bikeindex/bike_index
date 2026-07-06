import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='registration-show--photos'
// Swaps the large photo in [data-registration-show--photos-target=main] to match
// the clicked [data-registration-show--photos-target=thumbnail], points the
// enclosing link at the selected photo's original, and toggles
// data-registration-show--photos-active-class onto the selected thumbnail.
export default class extends Controller {
  static targets = ['main', 'link', 'thumbnail']
  static classes = ['active']

  select (event) {
    const thumbnail = event.currentTarget
    this.mainTarget.src = thumbnail.dataset.largeUrl
    this.mainTarget.alt = thumbnail.dataset.photoAlt
    if (this.hasLinkTarget) this.linkTarget.href = thumbnail.dataset.originalUrl
    this.thumbnailTargets.forEach((el) => el.classList.toggle(this.activeClass, el === thumbnail))
  }
}
