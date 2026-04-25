import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='landing-pages--bike-tiles'
export default class extends Controller {
  static targets = ['grid']
  static values = { images: Array }

  connect () {
    // Initialize bike tiles grid background
    this.generateTiles()
    this.ticking = false

    // Recalculate tiles on window resize
    this.handleResize = this.debounce(() => {
      this.gridTarget.innerHTML = ''
      this.generateTiles()
    }, 250)
    window.addEventListener('resize', this.handleResize)

    // Add subtle parallax effect to hero background on scroll
    this.handleScroll = () => {
      if (!this.ticking) {
        window.requestAnimationFrame(() => {
          const scrolled = window.pageYOffset
          const heroSection = this.element.closest('.le-hero-section')
          if (heroSection && scrolled < window.innerHeight) {
            this.gridTarget.style.transform = `translateY(${scrolled * 0.3}px)`
          }
          this.ticking = false
        })
        this.ticking = true
      }
    }

    window.addEventListener('scroll', this.handleScroll)
  }

  disconnect () {
    window.removeEventListener('scroll', this.handleScroll)
    window.removeEventListener('resize', this.handleResize)
  }

  debounce (func, wait) {
    let timeout
    return (...args) => {
      clearTimeout(timeout)
      timeout = setTimeout(() => func(...args), wait)
    }
  }

  generateTiles () {
    // Calculate how many tiles we need to fill the screen
    const tilesNeeded = Math.ceil(window.innerWidth / 130) * Math.ceil(window.innerHeight / 130) + 20
    const bikeImagesLength = this.imagesValue.length

    for (let i = 0; i < tilesNeeded; i++) {
      const tile = document.createElement('div')
      tile.className = 'le-bike-tile'
      const randomImage = this.imagesValue[Math.floor(Math.random() * bikeImagesLength)]
      tile.style.backgroundImage = `url('${randomImage}')`
      this.gridTarget.appendChild(tile)
    }
  }
}
