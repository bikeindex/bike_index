// Loads MapLibre GL + the PMTiles protocol from the CDN once, sharing the promise
// across every controller instance that renders our self-hosted basemap.
const MAPLIBRE_VERSION = '4.7.1'
const PMTILES_VERSION = '3.2.1'
const MAPLIBRE_JS = `https://cdn.jsdelivr.net/npm/maplibre-gl@${MAPLIBRE_VERSION}/dist/maplibre-gl.js`
const MAPLIBRE_CSS = `https://cdn.jsdelivr.net/npm/maplibre-gl@${MAPLIBRE_VERSION}/dist/maplibre-gl.css`
const PMTILES_JS = `https://cdn.jsdelivr.net/npm/pmtiles@${PMTILES_VERSION}/dist/pmtiles.js`

// Our self-hosted basemap. The style.json - and the vector tiles (.pmtiles),
// glyphs and sprites it references - live in the maps R2 bucket, see
// .github/workflows/upload-basemap.yml for uploading the tiles.
const MAPS_HOST = 'https://maps.bikeindex.org'
export const MAPS_STYLE_URL = `${MAPS_HOST}/basemap/style.json`

// OpenStreetMap's ODbL license requires crediting contributors on the map
export const OSM_ATTRIBUTION = '© OpenStreetMap contributors'

// Web Mercator meters per pixel at zoom 0 on the equator (MapLibre uses 512px tiles)
const METERS_PER_PIXEL_Z0 = 40075016.686 / 512

// circle-radius is in screen pixels, so it has to double every zoom level to keep
// covering the same ground. Returns interpolation stops for a fixed ground radius.
export function groundRadiusStops (radiusMeters, latitude) {
  const pixelsAtZoom0 = radiusMeters / (METERS_PER_PIXEL_Z0 * Math.cos(latitude * Math.PI / 180))
  return [
    'interpolate', ['exponential', 2], ['zoom'],
    0, pixelsAtZoom0,
    22, pixelsAtZoom0 * 2 ** 22
  ]
}

// Desktop expands the map over the page, so the site chrome stays reachable; on a
// phone that leaves too little map, so small screens get real fullscreen instead
const PAGE_EXPAND_QUERY = '(min-width: 48rem)'
// MapLibre's stylesheet is unlayered and our utilities live in @layer utilities, and
// unlayered rules win outright — so `.maplibregl-map { position: relative }` beats a
// plain `tw:fixed` on either map. Hence the important modifier.
const EXPANDED_CLASS = 'tw:fixed!'
// Above the header's 1040, since the expanded map covers the page
const EXPANDED_CLASSES = [EXPANDED_CLASS, 'tw:inset-0', 'tw:z-[1050]']

// A MapLibre control that expands the map to fill the page (or the screen, on
// mobile). Borrows MapLibre's own fullscreen button classes so it looks native.
export class ExpandControl {
  onAdd (map) {
    this.map = map
    this.button = document.createElement('button')
    this.button.type = 'button'
    this.button.innerHTML = '<span class="maplibregl-ctrl-icon" aria-hidden="true"></span>'
    this.button.addEventListener('click', () => this.toggle())
    this.label(false)

    // Document-scoped, so ignore anything else on the page going fullscreen —
    // two maps share this page and each resize costs a canvas repaint
    this.fullscreened = false
    this.onFullscreenChange = () => {
      const fullscreen = document.fullscreenElement === this.element
      if (fullscreen === this.fullscreened) return
      this.fullscreened = fullscreen
      this.reflect(fullscreen)
    }
    // Escape leaves an expanded map the way it leaves fullscreen
    this.onKeydown = (event) => { if (event.key === 'Escape') this.expandPage(false) }
    document.addEventListener('fullscreenchange', this.onFullscreenChange)

    this.container = document.createElement('div')
    this.container.className = 'maplibregl-ctrl maplibregl-ctrl-group'
    this.container.appendChild(this.button)
    return this.container
  }

  onRemove () {
    document.removeEventListener('fullscreenchange', this.onFullscreenChange)
    document.removeEventListener('keydown', this.onKeydown)
    this.container.remove()
    this.map = null
  }

  get element () { return this.map.getContainer() }

  get pageExpanded () { return this.element.classList.contains(EXPANDED_CLASS) }

  // Collapse the way we expanded — the viewport may have crossed the breakpoint
  // since (a rotated tablet, a resized window), and the other exit is a no-op
  toggle () {
    // fullscreenchange reflects the result, including an Escape the browser handles
    if (document.fullscreenElement === this.element) return document.exitFullscreen()
    if (this.pageExpanded) return this.expandPage(false)
    if (window.matchMedia(PAGE_EXPAND_QUERY).matches) return this.expandPage(true)
    this.element.requestFullscreen().catch(() => this.expandPage(true))
  }

  expandPage (expand) {
    EXPANDED_CLASSES.forEach((klass) => this.element.classList.toggle(klass, expand))
    if (expand) document.addEventListener('keydown', this.onKeydown)
    else document.removeEventListener('keydown', this.onKeydown)
    this.reflect(expand)
  }

  reflect (expanded) {
    this.label(expanded)
    this.map.resize()
  }

  label (expanded) {
    const text = expanded ? 'Exit expanded map' : 'Expand map'
    this.button.className = expanded ? 'maplibregl-ctrl-shrink' : 'maplibregl-ctrl-fullscreen'
    this.button.title = text
    this.button.setAttribute('aria-label', text)
  }
}

let mapLibrePromise

export function loadMapLibre () {
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
