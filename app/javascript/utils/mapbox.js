// Load Mapbox GL JS (script + stylesheet) from the CDN once, sharing the promise
// across every controller instance that needs a map. Loaded dynamically rather
// than via a plain <script src>: under Turbo a re-inserted external script loads
// async and no longer blocks a following inline script, so init could run before
// mapboxgl was defined.
const MAPBOX_VERSION = 'v1.11.0'
const MAPBOX_SRC = `https://api.mapbox.com/mapbox-gl-js/${MAPBOX_VERSION}/mapbox-gl.js`
const MAPBOX_CSS = `https://api.mapbox.com/mapbox-gl-js/${MAPBOX_VERSION}/mapbox-gl.css`

let mapboxPromise

export function loadMapbox () {
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
