export function urlParam (name) {
  return new URLSearchParams(window.location.search).get(name)
}

// replaceState, so the param survives a reload without stacking history entries
export function setUrlParam (name, value) {
  const url = new URL(window.location)
  url.searchParams.set(name, value)
  window.history.replaceState(window.history.state, '', url)
}
