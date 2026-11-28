export function urlParam (name) {
  return new URLSearchParams(window.location.search).get(name)
}

// replaceState, so the param survives a reload without stacking history entries. Its own pair
// alone, rather than through URLSearchParams, which would re-encode the rest of the query.
// A null value drops the param
export function setUrlParam (name, value) {
  const url = new URL(window.location)
  const pair = value === null ? null : `${encodeURIComponent(name)}=${encodeURIComponent(value).replaceAll('%2C', ',')}`
  const pairs = url.search.slice(1).split('&').filter(Boolean)
  const at = pairs.findIndex((each) => decodeURIComponent(each.split('=')[0]) === name)
  url.search = (at < 0 ? [...pairs, pair] : pairs.map((each, index) => index === at ? pair : each)).filter(Boolean).join('&')
  window.history.replaceState(window.history.state, '', url)
}
