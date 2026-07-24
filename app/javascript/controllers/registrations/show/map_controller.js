import { Controller } from '@hotwired/stimulus'
import { loadMapLibre, OSM_ATTRIBUTION } from 'utils/maplibre'

// Connects to data-controller='registrations--show--map'
// Lazy-loads MapLibre GL + the PMTiles protocol and renders a map centered on
// the coordinates, marking them with a dot (point) or a translucent red circle
// (approximate area).

// A fixed dot marking the exact spot
const POINT_PAINT = {
  'circle-radius': 7,
  'circle-color': 'red',
  'circle-opacity': 0.9,
  'circle-stroke-width': 2,
  'circle-stroke-color': 'white'
}

// A translucent circle approximating the area; grows with zoom
const CIRCLE_PAINT = (radiusBase) => ({
  'circle-radius': { stops: [[5, 5], [16, 240]], base: radiusBase },
  'circle-color': 'red',
  'circle-opacity': 0.4
})

export default class extends Controller {
  static targets = ['canvas', 'unavailable']
  static values = {
    styleUrl: String,
    latitude: Number,
    longitude: Number,
    radiusBase: { type: Number, default: 1.15 },
    point: Boolean
  }

  async connect () {
    if (!this.styleUrlValue) return
    try {
      const maplibregl = await loadMapLibre()
      if (!this.element.isConnected) return // disconnected while loading

      this.#render(maplibregl)
    } catch (error) {
      this.#showUnavailable(error)
    }
  }

  disconnect () {
    this.map?.remove()
    this.map = null
  }

  // WebGL/MapLibre can be unavailable (crawlers, headless browsers, disabled GPU,
  // blocked CDN). Reveal a message instead of leaving a blank box, and swallow the
  // rejection so it isn't reported as unhandled.
  #showUnavailable (error) {
    console.warn('Stolen map failed to render:', error)
    if (!this.hasUnavailableTarget) return

    this.canvasTarget.hidden = true
    this.unavailableTarget.hidden = false
  }

  #render (maplibregl) {
    const center = [this.longitudeValue, this.latitudeValue]
    this.map = new maplibregl.Map({
      container: this.canvasTarget,
      style: this.styleUrlValue,
      center,
      zoom: 13,
      maxZoom: 16,
      attributionControl: { customAttribution: OSM_ATTRIBUTION }
    })

    this.map.on('load', () => {
      this.map.addSource('location', {
        type: 'geojson',
        data: { type: 'Feature', geometry: { type: 'Point', coordinates: center } }
      })
      this.map.addLayer({
        id: 'location',
        type: 'circle',
        source: 'location',
        paint: this.pointValue ? POINT_PAINT : CIRCLE_PAINT(this.radiusBaseValue)
      })
    })
  }
}
