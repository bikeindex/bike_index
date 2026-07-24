// Loads MapLibre GL + the PMTiles protocol from the CDN once, sharing the promise
// across every controller instance that renders our self-hosted basemap.
const MAPLIBRE_VERSION = '4.7.1'
const PMTILES_VERSION = '3.2.1'
const MAPLIBRE_JS = `https://cdn.jsdelivr.net/npm/maplibre-gl@${MAPLIBRE_VERSION}/dist/maplibre-gl.js`
const MAPLIBRE_CSS = `https://cdn.jsdelivr.net/npm/maplibre-gl@${MAPLIBRE_VERSION}/dist/maplibre-gl.css`
const PMTILES_JS = `https://cdn.jsdelivr.net/npm/pmtiles@${PMTILES_VERSION}/dist/pmtiles.js`

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
