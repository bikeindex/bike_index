// URLSearchParams escapes the commas joining multiselect values and the slashes in vehicle ids,
// both readable unescaped in a query
export const readable = (url) => url.href.replaceAll('%2C', ',').replaceAll('%2F', '/')

export function replaceUrl (url) {
  window.history.replaceState(window.history.state, '', readable(url))
}
