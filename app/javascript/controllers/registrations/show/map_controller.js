import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='registrations--show--map'
// Lazy-loads Mapbox GL and renders a map centered on the coordinates, with a
// translucent red circle marking the (public, possibly obscured) location.
const MAPBOX_VERSION = 'v1.11.0'
const MAPBOX_SRC = `https://api.mapbox.com/mapbox-gl-js/${MAPBOX_VERSION}/mapbox-gl.js`
const MAPBOX_CSS = `https://api.mapbox.com/mapbox-gl-js/${MAPBOX_VERSION}/mapbox-gl.css`

export default class extends Controller {
  static values = {
    apiKey: String,
    latitude: Number,
    longitude: Number,
    radiusBase: { type: Number, default: 1.15 }
  }

  async connect () {
    if (!this.apiKeyValue) return
    const mapboxgl = await loadMapbox()
    if (!this.element.isConnected) return // disconnected while loading

    mapboxgl.accessToken = this.apiKeyValue
    this.#render(mapboxgl)
  }

  disconnect () {
    this.map?.remove()
    this.map = null
  }

  #render (mapboxgl) {
    const center = [this.longitudeValue, this.latitudeValue]
    this.map = new mapboxgl.Map({
      container: this.element,
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
        paint: {
          'circle-radius': { stops: [[5, 5], [16, 240]], base: this.radiusBaseValue },
          'circle-color': 'red',
          'circle-opacity': 0.4
        }
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
