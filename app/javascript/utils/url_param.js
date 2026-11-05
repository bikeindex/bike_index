export function urlParam (name) {
  return new URLSearchParams(window.location.search).get(name)
}

// replaceState, so the param survives a reload without stacking history entries. Its own pair
// alone, rather than through URLSearchParams, which would re-encode the rest of the query
export function setUrlParam (name, value) {
  const url = new URL(window.location)
  const pair = `${encodeURIComponent(name)}=${encodeURIComponent(value)}`
  const pairs = url.search.slice(1).split('&').filter(Boolean)
  const at = pairs.findIndex((each) => decodeURIComponent(each.split('=')[0]) === name)
  url.search = (at < 0 ? [...pairs, pair] : pairs.map((each, index) => index === at ? pair : each)).join('&')
  window.history.replaceState(window.history.state, '', url)
}
