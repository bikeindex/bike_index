import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='registrations--show--map'
// Lazy-loads Mapbox GL and renders a map centered on the coordinates, marking
// them with a dot (point) or a translucent red circle (approximate area).
const MAPBOX_VERSION = 'v1.11.0'
const MAPBOX_SRC = `https://api.mapbox.com/mapbox-gl-js/${MAPBOX_VERSION}/mapbox-gl.js`
const MAPBOX_CSS = `https://api.mapbox.com/mapbox-gl-js/${MAPBOX_VERSION}/mapbox-gl.css`

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
    apiKey: String,
    latitude: Number,
    longitude: Number,
    radiusBase: { type: Number, default: 1.15 },
    point: Boolean
  }

  async connect () {
    if (!this.apiKeyValue) return
    try {
      const mapboxgl = await loadMapbox()
      if (!this.element.isConnected) return // disconnected while loading

      mapboxgl.accessToken = this.apiKeyValue
      this.#render(mapboxgl)
    } catch (error) {
      this.#showUnavailable(error)
    }
  }

  disconnect () {
    this.map?.remove()
    this.map = null
  }

  // WebGL/Mapbox can be unavailable (crawlers, headless browsers, disabled GPU,
  // blocked CDN). Reveal a message instead of leaving a blank box, and swallow the
  // rejection so it isn't reported as unhandled.
  #showUnavailable (error) {
    console.warn('Stolen map failed to render:', error)
    if (!this.hasUnavailableTarget) return

    this.canvasTarget.hidden = true
    this.unavailableTarget.hidden = false
  }

  #render (mapboxgl) {
    const center = [this.longitudeValue, this.latitudeValue]
    this.map = new mapboxgl.Map({
      container: this.canvasTarget,
      style: 'mapbox://styles/mapbox/streets-v11',
      center,
      zoom: 13,
      maxZoom: 16
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

// Load Mapbox GL (script + stylesheet) once, shared across controller instances.
let mapboxPromise
function loadMapbox () {
  if (window.mapboxgl) return Promise.resolve(window.mapboxgl)
  if (mapboxPromise) return mapboxPromise

  if (!document.querySelector(`link[href="${MAPBOX_CSS}"]`)) {
    const link = document.createElement('link')
    link.rel = 'stylesheet'
    link.href = MAPBOX_CSS
    document.head.appendChild(link)
  }

  mapboxPromise = new Promise((resolve, reject) => {
    const script = document.createElement('script')
    script.src = MAPBOX_SRC
    script.onload = () => resolve(window.mapboxgl)
    script.onerror = reject
    document.head.appendChild(script)
  })
  return mapboxPromise
}
