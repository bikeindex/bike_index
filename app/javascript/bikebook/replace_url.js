// URLSearchParams escapes the commas joining multiselect values
export const withCommas = (url) => url.href.replaceAll('%2C', ',')

export function replaceUrl (url) {
  window.history.replaceState(window.history.state, '', withCommas(url))
}
