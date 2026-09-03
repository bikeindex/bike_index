import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='homepage--recovery-showcase'
export default class extends Controller {
  static targets = ['bikePhoto', 'next', 'prev', 'slide']
  static values = { currentIndex: { type: Number, default: 0 } }

  connect () {
    this.slidesCount = this.slideTargets.length
  }

  next () {
    this.goToSlide((this.currentIndexValue + 1) % this.slidesCount)
  }

  prev () {
    this.goToSlide((this.currentIndexValue - 1 + this.slidesCount) % this.slidesCount)
  }

  goToSlide (index) {
    // Hide current slide
    this.slideTargets[this.currentIndexValue].classList.add('tw:hidden')

    // Update index (this will trigger currentIndexValueChanged if you add that callback)
    this.currentIndexValue = index

    // Show new slide
    this.slideTargets[this.currentIndexValue].classList.remove('tw:hidden')

    // Update bike photo
    this.bikePhotoTarget.src = this.slideTargets[this.currentIndexValue].dataset.imageUrl
  }
}
