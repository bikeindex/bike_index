import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--assign-bike-sticker'
// When a bike_sticker param is present, wires up assign link hrefs
export default class extends Controller {
  static values = { stickerPath: String }

  connect () {
    if (!this.stickerPathValue) return
    this.updateLinks()
  }

  updateLinks () {
    const basePath = this.stickerPathValue
    const separator = basePath.includes('?') ? '&' : '?'
    this.element.querySelectorAll('.assign_bike_sticker_cell a[data-bike-id]').forEach(link => {
      const bikeId = link.dataset.bikeId
      link.href = `${basePath}${separator}bike_id=${bikeId}`
      link.dataset.turboMethod = 'put'
      link.dataset.turboFrame = '_top'
    })
  }
}
