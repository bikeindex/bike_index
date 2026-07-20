import { Controller } from '@hotwired/stimulus'

// Renders the Mapbox map showing a stolen/impounded bike's location.
// Connects to data-controller='stolen-map'
//
// Mapbox GL is loaded dynamically from the CDN here rather than via a plain
// <script src> in the view: under Turbo, a re-inserted external script loads
// async and no longer blocks the following inline script, so init ran before
// mapboxgl was defined (ReferenceError: mapboxgl is not defined).
const MAPBOX_VERSION = 'v1.11.0'
const MAPBOX_JS = `https://api.mapbox.com/mapbox-gl-js/${MAPBOX_VERSION}/mapbox-gl.js`
const MAPBOX_CSS = `https://api.mapbox.com/mapbox-gl-js/${MAPBOX_VERSION}/mapbox-gl.css`

export default class extends Controller {
  static targets = ['canvas']
  static values = { token: String, lng: Number, lat: Number, radiusBase: Number }

  connect () {
    // WebGL can be unavailable (crawlers, headless browsers, disabled GPU); the
    // map just doesn't render. Swallow it so it isn't reported as an unhandled
    // promise rejection.
    loadMapbox()
      .then(() => this.renderMap())
      .catch((error) => console.warn('Stolen map failed to render:', error))
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

// Load the Mapbox GL script + stylesheet once, sharing the promise across maps.
let mapboxLoading

function loadMapbox () {
  if (window.mapboxgl) return Promise.resolve()

  mapboxLoading ||= new Promise((resolve, reject) => {
    const link = document.createElement('link')
    link.rel = 'stylesheet'
    link.href = MAPBOX_CSS
    document.head.appendChild(link)

    const script = document.createElement('script')
    script.src = MAPBOX_JS
    script.onload = resolve
    script.onerror = reject
    document.head.appendChild(script)
  })

  return mapboxLoading
}
