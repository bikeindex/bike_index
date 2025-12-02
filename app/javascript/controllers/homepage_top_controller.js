import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='homepage-top'
export default class extends Controller {
  static targets = [
    'bikeTilesGrid'
  ]
  static values = { bikeTileImages: Array }

  connect() {
    console.log(this.bikeTileImagesValue)
    this.generateTiles()
  }

  generateTiles() {
    // Calculate how many tiles we need to fill the screen plus overflow
    const tilesNeeded = Math.ceil((window.innerWidth * 1.2) / 130) * Math.ceil((window.innerHeight * 1.2) / 130);

    // Calculate grid dimensions
    const columns = Math.ceil((window.innerWidth * 1.2) / 130);
    // Length for the random
    const bikeImagesLength = this.bikeTileImagesValue.length

    let lastImage = null;
    let lastRowImages = [];

    for (let i = 0; i < tilesNeeded; i++) {
      const tile = document.createElement('div');
      tile.className = 'bike-tile';

      // Get column position to check tile above
      const col = i % columns;
      const imageAbove = lastRowImages[col];

      // Select random image that's different from left neighbor and tile above
      let randomImage;
      let attempts = 0;
      do {
        randomImage = this.bikeTileImagesValue[Math.floor(Math.random() * bikeImagesLength)];
        attempts++;
      } while ((randomImage === lastImage || randomImage === imageAbove) && attempts < 50);

      tile.style.backgroundImage = `url('${randomImage}')`;

      // Add random slight rotation variation
      const randomRotation = (Math.random() - 0.5) * 10;
      tile.style.transform = `rotate(${5 + randomRotation}deg)`;

      this.bikeTilesGridTarget.appendChild(tile);

      // Update tracking
      lastImage = randomImage;
      lastRowImages[col] = randomImage;
    }
  }
}
