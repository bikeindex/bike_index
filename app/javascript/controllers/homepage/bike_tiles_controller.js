import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='homepage--bike-tiles'
export default class extends Controller {
  static targets = ['grid']
  static values = { images: Array }

  connect () {
    this.generateTiles()

    this.handleResize = this.debounce(() => {
      this.generateTiles()
    }, 250)

    window.addEventListener('resize', this.handleResize)
  }

  disconnect () {
    window.removeEventListener('resize', this.handleResize)
  }

  debounce (func, wait) {
    let timeout
    return function executedFunction (...args) {
      clearTimeout(timeout)
      timeout = setTimeout(() => func(...args), wait)
    }
  }

  generateTiles () {
    // Calculate how many tiles we need to fill the screen plus overflow
    const tilesNeeded = Math.ceil((window.innerWidth * 1.2) / 130) * Math.ceil((window.innerHeight * 1.2) / 130)

    // Calculate grid dimensions
    const columns = Math.ceil((window.innerWidth * 1.2) / 130)
    // Length for the random
    const bikeImagesLength = this.imagesValue.length

    let lastImage = null
    const lastRowImages = []

    for (let i = 0; i < tilesNeeded; i++) {
      const tile = document.createElement('div')
      tile.className = 'bike-tile'

      // Get column position to check tile above
      const col = i % columns
      const imageAbove = lastRowImages[col]

      // Select random image that's different from left neighbor and tile above
      let randomImage
      let attempts = 0
      do {
        randomImage = this.imagesValue[Math.floor(Math.random() * bikeImagesLength)]
        attempts++
      } while ((randomImage === lastImage || randomImage === imageAbove) && attempts < 50)

      // Apply styles to interior span element, to prevent hover flicker
      const span = document.createElement('span')
      span.style.backgroundImage = `url('${randomImage}')`

      // tile.style.backgroundImage = `url('${randomImage}')`;

      // Add random slight rotation variation
      const randomRotation = (Math.random() - 0.5) * 10
      span.style.transform = `rotate(${5 + randomRotation}deg)`

      tile.appendChild(span)
      this.gridTarget.appendChild(tile)

      // Update tracking
      lastImage = randomImage
      lastRowImages[col] = randomImage
    }

    // Select a random tile to be the "stolen alert" tile - around central region but not behind shields/text
    const allTiles = this.gridTarget.querySelectorAll('.bike-tile')
    if (allTiles.length > 0) {
      // Get hero content position to find central area
      const heroContent = document.querySelector('.hero-content')
      const heroRect = heroContent.getBoundingClientRect()

      // Define ring around the hero text (outer radius minus inner exclusion zone)
      const centerX = window.innerWidth / 2
      const centerY = heroRect.top + (heroRect.height / 2)
      const outerRadiusX = 500 // Outer horizontal radius
      const outerRadiusY = 400 // Outer vertical radius
      const innerRadiusX = 250 // Inner exclusion horizontal radius (where shields/text are)
      const innerRadiusY = 200 // Inner exclusion vertical radius

      const ringTiles = Array.from(allTiles).filter(tile => {
        const rect = tile.getBoundingClientRect()
        const tileCenterX = rect.left + (rect.width / 2)
        const tileCenterY = rect.top + (rect.height / 2)

        const distanceX = Math.abs(tileCenterX - centerX)
        const distanceY = Math.abs(tileCenterY - centerY)

        // Check if tile is in the ring (within outer radius but outside inner radius)
        const inOuterEllipse = distanceX <= outerRadiusX && distanceY <= outerRadiusY
        const inInnerEllipse = distanceX <= innerRadiusX && distanceY <= innerRadiusY

        return inOuterEllipse && !inInnerEllipse &&
             rect.top >= 0 &&
             rect.bottom <= window.innerHeight
      })

      // Remove any existing stolen alert tiles (important when resizing the window)
      this.gridTarget.querySelectorAll('.bike-tile.stolen-alert').forEach(tile => {
        tile.classList.remove('stolen-alert', 'tw:cursor-pointer')
      })

      // Select from ring tiles only
      if (ringTiles.length > 0) {
        const randomIndex = Math.floor(Math.random() * ringTiles.length)
        const stolenTile = ringTiles[randomIndex]
        stolenTile.classList.add('stolen-alert', 'tw:cursor-pointer')

        // Make it clickable to scroll to stolen section
        stolenTile.addEventListener('click', function () {
          const stolenSection = document.querySelector('.stolen-question-section')
          if (stolenSection) {
            stolenSection.scrollIntoView({ behavior: 'smooth' })
          }
        })
      }
    }
  }
}
