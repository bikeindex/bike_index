import { Controller } from '@hotwired/stimulus'
import { ExpandControl, groundRadiusStops, loadMapLibre, MAPS_STYLE_URL, OSM_ATTRIBUTION, showMapUnavailable } from 'utils/maplibre'

/* global IntersectionObserver */

// Connects to data-controller='registrations--show--map'
// Renders a map centered on the coordinates, marking them with a pin (point) or
// a translucent red circle (approximate area).

// A translucent circle covering the approximate area
const CIRCLE_PAINT = (radiusMeters, latitude) => ({
  'circle-radius': groundRadiusStops(radiusMeters, latitude),
  'circle-color': 'red',
  'circle-opacity': 0.4
})

export default class extends Controller {
  static targets = ['canvas', 'unavailable', 'pin']
  static values = {
    latitude: Number,
    longitude: Number,
    radiusMeters: Number
  }

  // Load only once on screen — it can sit in a collapsed panel or below the fold
  connect () {
    this.observer = new IntersectionObserver((entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return
      this.observer.disconnect()
      this.#load()
    }, { rootMargin: '200px' })
    this.observer.observe(this.element)
  }

  async #load () {
    try {
      const maplibregl = await loadMapLibre()
      if (!this.element.isConnected) return // disconnected while loading

      this.#render(maplibregl)
    } catch (error) {
      showMapUnavailable(error, {
        source: this.identifier,
        map: this.map,
        canvas: this.canvasTarget,
        message: this.hasUnavailableTarget ? this.unavailableTarget : null
      })
      this.map = null
    }
  }

  disconnect () {
    this.observer?.disconnect()
    this.map?.remove()
    this.map = null
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
    this.map.addControl(new ExpandControl(), 'top-right')

    if (this.hasPinTarget) {
      const element = this.pinTarget.content.firstElementChild.cloneNode(true)
      new maplibregl.Marker({ element, anchor: 'bottom' }).setLngLat(center).addTo(this.map)
      return
    }

    this.map.on('load', () => {
      this.map.addSource('location', {
        type: 'geojson',
        data: { type: 'Feature', geometry: { type: 'Point', coordinates: center } }
      })
      this.map.addLayer({
        id: 'location',
        type: 'circle',
        source: 'location',
        paint: CIRCLE_PAINT(this.radiusMetersValue, this.latitudeValue)
      })
    })
  }
}
