import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='law-enforcement--bike-tiles'
export default class extends Controller {
  static targets = ['grid']
  static values = { images: Array }

  connect () {
    this.generateTiles()

    this.handleResize = this.debounce(() => {
      this.gridTarget.innerHTML = ''
      this.generateTiles()
    }, 250)

    window.addEventListener('resize', this.handleResize)

    // Parallax on scroll
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
    window.removeEventListener('resize', this.handleResize)
    window.removeEventListener('scroll', this.handleScroll)
  }

  debounce (func, wait) {
    let timeout
    return (...args) => {
      clearTimeout(timeout)
      timeout = setTimeout(() => func(...args), wait)
    }
  }

  generateTiles () {
    const columns = Math.ceil(window.innerWidth / 130)
    const rows = Math.ceil(window.innerHeight / 130) + 2
    const tilesNeeded = columns * rows
    const bikeImagesLength = this.imagesValue.length

    let lastImage = null
    const lastRowImages = []

    for (let i = 0; i < tilesNeeded; i++) {
      const tile = document.createElement('div')
      tile.className = 'le-bike-tile'

      const col = i % columns
      const imageAbove = lastRowImages[col]

      let randomImage
      let attempts = 0
      do {
        randomImage = this.imagesValue[Math.floor(Math.random() * bikeImagesLength)]
        attempts++
      } while ((randomImage === lastImage || randomImage === imageAbove) && attempts < 50)

      tile.style.backgroundImage = `url('${randomImage}')`

      this.gridTarget.appendChild(tile)

      lastImage = randomImage
      lastRowImages[col] = randomImage
    }
  }
}
