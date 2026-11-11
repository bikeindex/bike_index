// URLSearchParams escapes the commas joining multiselect values, the slashes in vehicle ids and the braces and colons of
// what's picked for each, all readable unescaped in a query
export const readable = (url) => url.href.replace(/%2[CF]|%7[BD]|%3A/g, decodeURIComponent)

export function replaceUrl (url) {
  const href = readable(url)
  if (href !== window.location.href) window.history.replaceState(window.history.state, '', href)
}
