// to_query: keys sorted and CGI-escaped, blank values dropped, commas and slashes left readable
export const toQuery = (params) => {
  const cgiEscape = (text) => encodeURIComponent(text).replace(/[!'()*]/g, (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`)
    .replace(/%20/g, '+').replace(/%2C/g, ',').replace(/%2F/g, '/')
  return Object.keys(params).filter((key) => String(params[key] ?? '').trim() !== '').sort()
    .map((key) => `${cgiEscape(key)}=${cgiEscape(params[key])}`).join('&')
}
