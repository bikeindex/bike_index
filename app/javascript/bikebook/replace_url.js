// URLSearchParams escapes the commas joining multiselect values and the slashes in vehicle ids,
// both readable unescaped in a query
export const readable = (url) => url.href.replace(/%2[CF]/g, decodeURIComponent)

export function replaceUrl (url) {
  const href = readable(url)
  if (href !== window.location.href) window.history.replaceState(window.history.state, '', href)
}

// The page's URL as the query it renders from, a model's own page /bikebook/m/… reading as /bikebook?vehicle_models=m/…
export function queryUrl () {
  const url = new URL(window.location.href)
  const id = url.pathname.match(/^\/bikebook\/(.+)/)?.[1]
  if (id) {
    url.pathname = '/bikebook'
    url.searchParams.set('vehicle_models', id)
  }
  return url
}
