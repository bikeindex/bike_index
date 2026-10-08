// URLSearchParams escapes the commas joining multiselect values and the slashes in vehicle ids,
// both readable unescaped in a query
export const readable = (url) => url.href.replace(/%2[CF]/g, decodeURIComponent)

export function replaceUrl (url) {
  const href = readable(url)
  if (href !== window.location.href) window.history.replaceState(window.history.state, '', href)
}
