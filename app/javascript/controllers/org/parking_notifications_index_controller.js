import { Controller } from '@hotwired/stimulus'
import { ExpandControl, loadMapLibre, MAPS_STYLE_URL, OSM_ATTRIBUTION, showMapUnavailable } from 'utils/maplibre'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='org--parking-notifications-index'
// Pins every loaded notification on the map, and narrows the table to the ones in view
export default class extends Controller {
  static targets = ['canvas', 'unavailable', 'pin', 'placePin', 'placeForm', 'placeInput', 'redo', 'fit',
    'visibleCount', 'table', 'row', 'emptyRow', 'repeatForm', 'submit']

  static values = {
    latitude: Number,
    longitude: Number,
    boundingBox: Array, // [south, west, north, east]
    place: Array // [latitude, longitude]
  }

  async connect () {
    try {
      const maplibregl = await loadMapLibre()
      if (!this.element.isConnected) return // disconnected while loading

      this.#render(maplibregl)
    } catch (error) {
      showMapUnavailable(error, { source: this.identifier, map: this.map, canvas: this.canvasTarget, message: this.unavailableTarget })
      this.map = null
    }
  }

  disconnect () {
    this.map?.remove()
    this.map = null
  }

  redoSearch () {
    const bounds = this.map.getBounds()
    this.#visit({
      search_southwest_coords: coordinates(bounds.getSouthWest()),
      search_northeast_coords: coordinates(bounds.getNorthEast())
    })
  }

  // With nothing inside the searched area there's nothing to fit, so search everywhere
  fit () {
    if (this.#nothingAtLocation) {
      this.#visit({ search_southwest_coords: null, search_northeast_coords: null })
    } else {
      this.#fitToMarkers()
      this.#forgetPlace()
    }
  }

  // A place outside the searched area would show none of its notifications
  searchPlace (event) {
    event.preventDefault()
    this.#visit({
      map_location: this.placeInputTarget.value.trim() || null,
      search_southwest_coords: null,
      search_northeast_coords: null
    })
  }

  showOnMap (event) {
    const row = event.currentTarget.closest('tr')
    if (!this.markers?.has(row)) return

    this.canvasTarget.scrollIntoView({ behavior: 'smooth', block: 'center' })
    this.#openPopup(row)
  }

  closePopup () {
    this.popup?.remove()
  }

  showMultiselect (event) {
    collapse('hide', event.currentTarget)
    collapse('show', this.repeatFormTarget)
    this.tableTarget.classList.add('show-multiselect')
  }

  updateSubmitText (event) {
    this.submitTarget.value = event.target.value === 'mark_retrieved' ? 'Resolve notifications' : 'Create notifications'
  }

  #render (maplibregl) {
    const [south, west, north, east] = this.boundingBoxValue
    this.map = new maplibregl.Map({
      container: this.canvasTarget,
      style: MAPS_STYLE_URL,
      center: [this.longitudeValue, this.latitudeValue],
      zoom: 13,
      bounds: this.#hasBoundingBox ? [[west, south], [east, north]] : undefined,
      cooperativeGestures: true,
      attributionControl: { customAttribution: OSM_ATTRIBUTION }
    })
    const placeForm = this.placeFormTarget.content.firstElementChild.cloneNode(true)
    this.map.addControl({ onAdd: () => placeForm, onRemove: () => placeForm.remove() }, 'top-left')
    this.map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right')
    this.map.addControl(new ExpandControl(), 'top-right')
    this.popup = new maplibregl.Popup({ offset: 32, maxWidth: 'min(90vw, 60rem)', closeOnClick: false, focusAfterOpen: false })
    this.popup.on('close', () => this.#markCurrentPin(null))

    // rowTargets re-queries the DOM on every read, and every moveend reads it
    this.rows = this.rowTargets
    this.markers = new Map(this.rows.filter((row) => row.dataset.latitude && row.dataset.longitude)
      .map((row) => [row, this.#addMarker(maplibregl, row)]))

    if (this.placeValue.length) {
      const [latitude, longitude] = this.placeValue
      const element = this.placePinTarget.content.firstElementChild.cloneNode(true)
      new maplibregl.Marker({ element }).setLngLat([longitude, latitude]).addTo(this.map)
      this.map.jumpTo({ center: [longitude, latitude], zoom: 14 })
    } else if (!this.#hasBoundingBox) {
      this.#fitToMarkers({ animate: false })
    }

    this.#filterRows()
    // Only a move the user made changes what "current location" means
    this.map.on('moveend', (event) => {
      this.#filterRows()
      if (!event.originalEvent) return
      collapse('show', this.redoTarget)
      this.#forgetPlace()
    })
  }

  #addMarker (maplibregl, row) {
    const element = this.pinTarget.content.firstElementChild.cloneNode(true)
    element.addEventListener('click', () => this.#openPopup(row))
    return new maplibregl.Marker({ element, anchor: 'bottom' })
      .setLngLat([Number(row.dataset.longitude), Number(row.dataset.latitude)])
      .addTo(this.map)
  }

  #openPopup (row) {
    const marker = this.markers.get(row)
    this.popup.setLngLat(marker.getLngLat())
      .setDOMContent(this.#popupContent(row))
      .addTo(this.map)
    // After addTo, which closes the popup it reopens
    this.#markCurrentPin(marker.getElement())
  }

  #markCurrentPin (pin) {
    this.currentPin?.removeAttribute('aria-current')
    pin?.setAttribute('aria-current', 'true')
    this.currentPin = pin
  }

  // The row, under the table's header, without the map and checkbox columns
  #popupContent (row) {
    const table = this.tableTarget.cloneNode(false)
    const head = this.tableTarget.tHead.cloneNode(true)
    // The sort links would re-sort the page from inside a popup
    head.querySelectorAll('a').forEach((link) => link.replaceWith(...link.childNodes))
    table.append(head)
    const clone = row.cloneNode(true)
    clone.classList.remove('tw:hidden', 'tw:hidden!')
    table.createTBody().append(clone)
    table.querySelectorAll('.map-cell, .multiselect-cell').forEach((cell) => cell.remove())

    const wrapper = document.createElement('div')
    wrapper.className = 'tw:overflow-x-auto'
    wrapper.append(table)
    // Clones inside the controller would register as its targets
    wrapper.querySelectorAll('[data-org--parking-notifications-index-target]')
      .forEach((element) => element.removeAttribute('data-org--parking-notifications-index-target'))
    return wrapper
  }

  #fitToMarkers (options = {}) {
    if (!this.markers.size) return

    const lngLats = [...this.markers.values()].map((marker) => marker.getLngLat())
    const lngs = lngLats.map(({ lng }) => lng)
    const lats = lngLats.map(({ lat }) => lat)
    const bounds = [[Math.min(...lngs), Math.min(...lats)], [Math.max(...lngs), Math.max(...lats)]]
    this.map.fitBounds(bounds, { padding: 40, maxZoom: 16, ...options })
  }

  #filterRows () {
    const bounds = this.map.getBounds()
    const visibleRows = new Set(this.rows.filter((row) => this.markers.has(row) && bounds.contains(this.markers.get(row).getLngLat())))
    // Not collapse(): its per-row computed-style read, between these writes, forces a recalc each
    this.rows.forEach((row) => {
      row.classList.toggle('tw:hidden!', !visibleRows.has(row))
      // Disabled, a hidden row's check neither submits nor gets selected by "Select all"
      const checkbox = row.querySelector('input[type=checkbox]')
      if (checkbox) checkbox.disabled = !visibleRows.has(row)
    })
    collapse(visibleRows.size ? 'hide' : 'show', this.emptyRowTarget, 0)
    this.visibleCountTarget.textContent = visibleRows.size.toLocaleString()

    const allVisible = visibleRows.size === this.markers.size && !this.#nothingAtLocation
    collapse(allVisible ? 'hide' : 'show', this.fitTarget)
  }

  get #hasBoundingBox () {
    return this.boundingBoxValue.length === 4
  }

  get #nothingAtLocation () {
    return this.#hasBoundingBox && !this.rows.length
  }

  // Once the map leaves the searched place, the URL shouldn't reopen on it
  #forgetPlace () {
    const url = new URL(window.location.href)
    if (!url.searchParams.has('map_location')) return

    url.searchParams.delete('map_location')
    window.history.replaceState(window.history.state, '', url)
  }

  // Merged into the current URL, so the rest of the search carries over
  #visit (params) {
    const url = new URL(window.location.href)
    url.searchParams.delete('page')
    if (!('map_location' in params)) url.searchParams.delete('map_location')
    Object.entries(params).forEach(([key, value]) => {
      if (value) url.searchParams.set(key, value)
      else url.searchParams.delete(key)
    })
    window.location.href = url.pathname + url.search
  }
}

const coordinates = (lngLat) => `${lngLat.lat.toFixed(6)},${lngLat.lng.toFixed(6)}`
