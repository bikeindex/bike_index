import { Controller } from '@hotwired/stimulus'
import { loadMapbox } from 'utils/mapbox'

// Renders the Mapbox map showing a stolen/impounded bike's location.
// Connects to data-controller='stolen-map'

export default class extends Controller {
  static targets = ['canvas', 'unavailable']
  static values = { token: String, lng: Number, lat: Number, radiusBase: Number }

  connect () {
    loadMapbox()
      .then(() => this.renderMap())
      .catch((error) => this.showUnavailable(error))
  }

  // WebGL/Mapbox can be unavailable (crawlers, headless browsers, disabled GPU,
  // CDN blocked). Replace the blank canvas with a message rather than leaving an
  // empty box - and swallow the rejection so it isn't reported as unhandled.
  showUnavailable (error) {
    console.warn('Stolen map failed to render:', error)
    if (!this.hasUnavailableTarget) return

    this.canvasTarget.hidden = true
    this.unavailableTarget.hidden = false
  }

  disconnect () {
    this.map?.remove()
  }

  renderMap () {
    const { mapboxgl } = window
    mapboxgl.accessToken = this.tokenValue
    const lngLat = [this.lngValue, this.latValue]

    const map = new mapboxgl.Map({
      container: this.canvasTarget,
      style: 'mapbox://styles/mapbox/streets-v11',
      center: lngLat,
      zoom: 13,
      maxZoom: 16
    })
    this.map = map

    map.on('load', () => {
      map.addSource('stolenBikeCircle', {
        type: 'geojson',
        data: {
          type: 'FeatureCollection',
          features: [{ type: 'Feature', geometry: { type: 'Point', coordinates: lngLat } }]
        }
      })

      map.addLayer({
        id: 'stolenBikeLocation',
        type: 'circle',
        source: 'stolenBikeCircle',
        paint: {
          'circle-radius': { stops: [[5, 5], [16, 240]], base: this.radiusBaseValue },
          'circle-color': 'red',
          'circle-opacity': 0.4
        }
      })
    })
  }
}
