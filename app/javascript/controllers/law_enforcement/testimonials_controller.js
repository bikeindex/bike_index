import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='law-enforcement--testimonials'
export default class extends Controller {
  static targets = ['testimonial', 'dots']

  connect () {
    this.currentIndex = 0
    this.createDots()
    this.autoAdvanceInterval = setInterval(() => this.next(), 8000)
  }

  disconnect () {
    clearInterval(this.autoAdvanceInterval)
  }

  createDots () {
    this.testimonialTargets.forEach((_, index) => {
      const dot = document.createElement('button')
      dot.className = `le-testimonial-dot${index === 0 ? ' active' : ''}`
      dot.addEventListener('click', () => this.show(index))
      this.dotsTarget.appendChild(dot)
    })
  }

  prev () {
    const count = this.testimonialTargets.length
    this.show((this.currentIndex - 1 + count) % count)
  }

  next () {
    const count = this.testimonialTargets.length
    this.show((this.currentIndex + 1) % count)
  }

  show (index) {
    this.testimonialTargets.forEach(t => t.classList.remove('active'))
    this.dotsTarget.querySelectorAll('.le-testimonial-dot').forEach(d => d.classList.remove('active'))

    this.testimonialTargets[index].classList.add('active')
    this.dotsTarget.querySelectorAll('.le-testimonial-dot')[index]?.classList.add('active')

    this.currentIndex = index

    // Reset auto-advance timer
    clearInterval(this.autoAdvanceInterval)
    this.autoAdvanceInterval = setInterval(() => this.next(), 8000)
  }
}
