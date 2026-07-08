import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='registration-show--photos'
// Swaps the large photo in [data-registration-show--photos-target=main] to match
// the clicked [data-registration-show--photos-target=thumbnail], points the
// enclosing link at the selected photo's original, and toggles
// data-registration-show--photos-active-class onto the selected thumbnail.
// A broken main image drops its enclosing link so it isn't clickable.
export default class extends Controller {
  static targets = ['main', 'link', 'thumbnail']
  static classes = ['active']

  connect () {
    // The error event may have fired before this controller connected
    if (this.hasMainTarget && this.mainTarget.complete && this.mainTarget.naturalWidth === 0) {
      this.disableLink()
    }
  }

  select (event) {
    const thumbnail = event.currentTarget
    this.mainTarget.src = thumbnail.dataset.largeUrl
    this.mainTarget.alt = thumbnail.dataset.photoAlt
    if (this.hasLinkTarget) {
      this.linkTarget.setAttribute('href', thumbnail.dataset.originalUrl)
      this.linkTarget.classList.remove('tw:cursor-default')
    }
    this.thumbnailTargets.forEach((el) => el.classList.toggle(this.activeClass, el === thumbnail))
  }

  brokenImage () {
    this.disableLink()
  }

  // A link without an href isn't a hyperlink (and reverts to the default cursor)
  disableLink () {
    if (!this.hasLinkTarget) return
    this.linkTarget.removeAttribute('href')
    this.linkTarget.classList.add('tw:cursor-default')
  }
}
