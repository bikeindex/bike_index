import { Controller } from '@hotwired/stimulus'
import { loadMapLibre, MAPS_STYLE_URL, OSM_ATTRIBUTION } from 'utils/maplibre'

// Connects to data-controller='registrations--show--map'
// Renders a map centered on the coordinates, marking them with a dot (point) or
// a translucent red circle (approximate area).

// A fixed dot marking the exact spot
const POINT_PAINT = {
  'circle-radius': 7,
  'circle-color': 'red',
  'circle-opacity': 0.9,
  'circle-stroke-width': 2,
  'circle-stroke-color': 'white'
}

// Web Mercator meters per pixel at zoom 0 on the equator (MapLibre uses 512px tiles)
const METERS_PER_PIXEL_Z0 = 40075016.686 / 512

// A translucent circle covering the approximate area. circle-radius is in screen
// pixels, so it has to double every zoom level to keep covering the same ground.
const CIRCLE_PAINT = (radiusMeters, latitude) => {
  const pixelsAtZoom0 = radiusMeters / (METERS_PER_PIXEL_Z0 * Math.cos(latitude * Math.PI / 180))
  return {
    'circle-radius': [
      'interpolate', ['exponential', 2], ['zoom'],
      0, pixelsAtZoom0,
      22, pixelsAtZoom0 * 2 ** 22
    ],
    'circle-color': 'red',
    'circle-opacity': 0.4
  }
}

export default class extends Controller {
  static targets = ['canvas', 'unavailable']
  static values = {
    latitude: Number,
    longitude: Number,
    radiusMeters: Number,
    point: Boolean
  }

  async connect () {
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
      style: MAPS_STYLE_URL,
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
        paint: this.pointValue ? POINT_PAINT : CIRCLE_PAINT(this.radiusMetersValue, this.latitudeValue)
      })
    })
  }
}
