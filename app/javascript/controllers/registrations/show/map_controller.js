import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='registrations--show--map'
// Lazy-loads MapLibre GL + the PMTiles protocol and renders a map centered on
// the coordinates, marking them with a dot (point) or a translucent red circle
// (approximate area).
const MAPLIBRE_VERSION = '4.7.1'
const PMTILES_VERSION = '3.2.1'
const MAPLIBRE_JS = `https://cdn.jsdelivr.net/npm/maplibre-gl@${MAPLIBRE_VERSION}/dist/maplibre-gl.js`
const MAPLIBRE_CSS = `https://cdn.jsdelivr.net/npm/maplibre-gl@${MAPLIBRE_VERSION}/dist/maplibre-gl.css`
const PMTILES_JS = `https://cdn.jsdelivr.net/npm/pmtiles@${PMTILES_VERSION}/dist/pmtiles.js`

// OpenStreetMap's ODbL license requires crediting contributors on the map
const ATTRIBUTION = '© OpenStreetMap contributors'

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
      attributionControl: { customAttribution: ATTRIBUTION }
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

// Load MapLibre GL + the PMTiles protocol once, shared across controller instances.
let mapLibrePromise
function loadMapLibre () {
  if (window.maplibregl) return Promise.resolve(window.maplibregl)
  if (mapLibrePromise) return mapLibrePromise

  mapLibrePromise = (async () => {
    if (!document.querySelector(`link[href="${MAPLIBRE_CSS}"]`)) {
      const link = document.createElement('link')
      link.rel = 'stylesheet'
      link.href = MAPLIBRE_CSS
      document.head.appendChild(link)
    }
    await Promise.all([loadScript(MAPLIBRE_JS), loadScript(PMTILES_JS)])

    const { maplibregl, pmtiles } = window
    // Teach MapLibre to read pmtiles:// sources (the single-file vector tiles)
    maplibregl.addProtocol('pmtiles', new pmtiles.Protocol().tile)
    return maplibregl
  })()
  return mapLibrePromise
}

function loadScript (src) {
  return new Promise((resolve, reject) => {
    if (document.querySelector(`script[src="${src}"]`)) {
      resolve()
      return
    }
    const script = document.createElement('script')
    script.src = src
    script.onload = resolve
    script.onerror = reject
    document.head.appendChild(script)
  })
}
