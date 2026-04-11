import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='landing-page--bike-tiles'
export default class extends Controller {
  static targets = ['grid']
  static values = { images: Array }

  connect () {
    this.generateTiles()
  }

  generateTiles () {
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
