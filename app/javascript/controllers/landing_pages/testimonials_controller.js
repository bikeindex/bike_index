import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='landing-pages--testimonials'
export default class extends Controller {
  static targets = ['testimonial']

  // Testimonials carousel functionality
  connect () {
    this.currentIndex = 0
    // Create dots
    this.createDots()
    // Auto-advance testimonials every 8 seconds, pause on hover or keyboard focus
    this.startAutoAdvance()
    const wrapper = this.element.querySelector('.le-testimonials-carousel-wrapper')
    wrapper.addEventListener('mouseenter', () => this.pauseAutoAdvance())
    wrapper.addEventListener('mouseleave', () => this.startAutoAdvance())
    this.element.addEventListener('focusin', () => this.pauseAutoAdvance())
    this.element.addEventListener('focusout', (e) => {
      if (!this.element.contains(e.relatedTarget)) this.startAutoAdvance()
    })
  }

  disconnect () {
    clearInterval(this.autoAdvanceInterval)
  }

  startAutoAdvance () {
    clearInterval(this.autoAdvanceInterval)
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return

    this.autoAdvanceInterval = setInterval(() => this.next(), 8000)
  }

  pauseAutoAdvance () {
    clearInterval(this.autoAdvanceInterval)
  }

  createDots () {
    this.dotsContainer = this.element.querySelector('[data-testimonials-dots]')
    if (!this.dotsContainer) return

    this.testimonialTargets.forEach((_, index) => {
      const dot = document.createElement('button')
      dot.type = 'button'
      dot.className = 'le-testimonial-dot'
      dot.dataset.index = index
      dot.setAttribute('aria-label', `Testimonial ${index + 1}`)
      dot.addEventListener('click', () => this.goTo(index))
      if (index === 0) {
        dot.classList.add('active')
        dot.setAttribute('aria-current', 'true')
      }
      this.dotsContainer.appendChild(dot)
    })
  }

  get dots () {
    return this.dotsContainer ? this.dotsContainer.querySelectorAll('.le-testimonial-dot') : []
  }

  prev () {
    this.currentIndex = (this.currentIndex - 1 + this.testimonialTargets.length) % this.testimonialTargets.length
    this.show()
    this.resetAutoAdvance()
  }

  next () {
    this.currentIndex = (this.currentIndex + 1) % this.testimonialTargets.length
    this.show()
    this.resetAutoAdvance()
  }

  goTo (index) {
    this.currentIndex = index
    this.show()
    this.resetAutoAdvance()
  }

  resetAutoAdvance () {
    this.startAutoAdvance()
  }

  show () {
    this.testimonialTargets.forEach(t => t.classList.remove('active'))
    this.dots.forEach(d => {
      d.classList.remove('active')
      d.removeAttribute('aria-current')
    })

    this.testimonialTargets[this.currentIndex].classList.add('active')
    if (this.dots[this.currentIndex]) {
      this.dots[this.currentIndex].classList.add('active')
      this.dots[this.currentIndex].setAttribute('aria-current', 'true')
    }
  }
}
