import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='landing-page--testimonials'
export default class extends Controller {
  static targets = ['testimonial', 'dot']

  connect () {
    this.currentIndex = 0
    this.createDots()
    this.autoAdvanceInterval = setInterval(() => this.next(), 8000)
  }

  disconnect () {
    clearInterval(this.autoAdvanceInterval)
  }

  createDots () {
    const dotsContainer = this.element.querySelector('[data-testimonials-dots]')
    if (!dotsContainer) return

    this.testimonialTargets.forEach((_, index) => {
      const dot = document.createElement('button')
      dot.className = 'le-testimonial-dot'
      dot.dataset.landingPageTestimonialsTarget = 'dot'
      dot.dataset.index = index
      dot.dataset.action = 'click->landing-page--testimonials#goTo'
      if (index === 0) dot.classList.add('active')
      dotsContainer.appendChild(dot)
    })
  }

  prev () {
    this.currentIndex = (this.currentIndex - 1 + this.testimonialTargets.length) % this.testimonialTargets.length
    this.show()
  }

  next () {
    this.currentIndex = (this.currentIndex + 1) % this.testimonialTargets.length
    this.show()
  }

  goTo (event) {
    this.currentIndex = parseInt(event.currentTarget.dataset.index)
    this.show()
  }

  show () {
    this.testimonialTargets.forEach(t => t.classList.remove('active'))
    this.dotTargets.forEach(d => d.classList.remove('active'))

    this.testimonialTargets[this.currentIndex].classList.add('active')
    if (this.dotTargets[this.currentIndex]) {
      this.dotTargets[this.currentIndex].classList.add('active')
    }
  }
}
